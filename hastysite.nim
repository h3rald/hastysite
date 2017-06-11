import
  json,
  strutils,
  os,
  sequtils,
  tables,
  critbits,
  streams,
  parsecfg,
  logging

import
    packages/min/min,
    packages/hastyscribe/hastyscribe,
    packages/moustachu/src/moustachu

import
  config

type
  HastyDirs = object
    assets*: string
    contents*: string
    templates*: string
    output*: string
    temp*: string
    tempContents: string
  HastyFiles = object
    rules*: string
    scripts*: string
    metadata: string
    contents: seq[JsonNode]
    assets: seq[JsonNode]
  HastySite* = object
    settings*: JsonNode
    metadata*: JsonNode
    dirs*: HastyDirs
    files*: HastyFiles 
  NoMetadataException* = ref Exception
  DictionaryRequiredException* = ref Exception
  MetadataRequiredException* = ref Exception

#### min Library

proc hastysite_module*(i: In, hs: HastySite) =
  let def = i.define()

  def.symbol("metadata") do (i: In):
    i.push i.fromJson(hs.metadata)

  def.symbol("settings") do (i: In):
    i.push i.fromJson(hs.settings)

  def.symbol("contents") do (i: In):
    var contents = newSeq[MinValue](0)
    for j in hs.files.contents:
      contents.add i.fromJson(j)
    i.push contents.newVal(i.scope)

  def.symbol("assets") do (i: In):
    var assets = newSeq[MinValue](0)
    for j in hs.files.assets:
      assets.add i.fromJson(j)
    i.push assets.newVal(i.scope)

  def.symbol("output") do (i: In):
    i.push hs.dirs.output.newVal

  def.symbol("input-fread") do (i: In):
    var d: MinValue
    i.reqDictionary d
    let t = d.dget("type".newVal).getString 
    let path = d.dget("path".newVal).getString
    var contents = ""
    if t == "content":
      contents = readFile(hs.dirs.tempContents/path)
    else:
      contents = readFile(hs.dirs.assets/path)
    i.push contents.newVal

  def.symbol("output-fwrite") do (i: In):
    var d: MinValue
    i.reqDictionary d
    let id = d.dget("id".newVal).getString
    let ext = d.dget("ext".newVal).getString
    var contents = ""
    try:
      contents = d.dget("contents".newVal).getString
    except:
      raise MetadataRequiredException(msg: "Metadata key 'contents' not found in dictionary.")
    let outfile = hs.dirs.output/id&ext
    outfile.parentDir.createDir
    writeFile(outfile, contents)

  def.symbol("copy2output") do (i: In):
    var d: MinValue
    i.reqDictionary d
    let t = d.dget("type".newVal).getString 
    let path = d.dget("path".newVal).getString
    var infile, outfile: string
    if t == "content":
      infile = hs.dirs.tempContents/path
      outfile = hs.dirs.output/path
    else:
      infile = hs.dirs.assets/path
      outfile = hs.dirs.output/path
    notice " - Copying: ", infile, " -> ", outfile
    outfile.parentDir.createDir
    copyFileWithPermissions(infile, outfile)

  def.symbol("mustache") do (i: In):
    var t, c: MinValue
    i.reqQuotationAndString c, t
    if not c.isDictionary:
      raise DictionaryRequiredException(msg: "No dictionary provided as template context.")
    let ctx = newContext(%c)
    let tplname = t.getString & ".mustache"
    let tpl = readFile(hs.dirs.templates/tplname)
    i.push tpl.render(ctx, hs.dirs.templates).newval

  def.symbol("markdown") do (i: In):
    var t, c: MinValue
    i.reqQuotationAndString c, t
    if not c.isDictionary:
      raise DictionaryRequiredException(msg: "No dictionary provided for markdown processor fields.")
    let options = HastyOptions(toc: false, output: nil, css: nil, watermark: nil, fragment: true)
    var fields = initTable[string, proc():string]()
    for item in c.qVal:
      fields[item.qVal[0].getString] = proc(): string = return $$item.qVal[1]
    var hastyscribe = newHastyScribe(options, fields)
    let file = t.getString()
    i.push hastyscribe.compileFragment(file, hs.dirs.contents).newVal

  def.finalize("hastysite")
      
#### Helper Functions

proc preprocessContent(file, dir: string, obj: var JsonNode): string =
  let fileid = file.replace(dir, "")
  var f: File
  discard f.open(file)
  var s, cfg = ""
  result = ""
  var delimiter = 0
  try:
    while f.readLine(s):
      if delimiter  >= 2:
        result &= s&"\n"
      else:
        if s.startsWith("----"):
          delimiter.inc
        else:
          cfg &= s&"\n"
  except:
    discard
  if not obj.hasKey("contents"):
    obj["contents"] = newJObject()
  var meta = newJObject();
  if delimiter < 2:
    result = cfg
  else:
    try:
      let ss = newStringStream(cfg)
      var p: CfgParser
      p.open(ss, file)
      while true:
        var e = next(p)
        case e.kind
        of cfgEof:
          break
        of cfgKeyValuePair:
          meta[e.key] = newJString(e.value)
        of cfgError:
          warn e.msg
        else:
          discard
      p.close()
    except:
      meta = newJObject()
  meta["path"] = %fileid
  meta["id"] = %fileid.changeFileExt("")
  meta["ext"] = %fileid.splitFile.ext
  obj["contents"][fileid] = meta
  f.close()

proc get(json: JsonNode, key, default: string): string =
  if json.hasKey(key):
    return json[key].getStr
  else:
    return default

proc quitIfNotExists(file: string) = 
  if not file.fileExists:
    quit("Error: File '$1' not found." % file)

proc contentMetadata(f, dir: string, meta: JsonNode): JsonNode = 
  result = newJObject()
  let fdata = f.splitFile
  let path = f.replace(dir & DirSep, "")
  if meta.hasKey("contents") and meta["contents"].hasKey(path):
    for key, value in meta["contents"][path].pairs:
      result[key] = value
  result["path"] = %path
  result["type"] = %"content"
  result["id"] = %path.changeFileExt("")
  result["ext"] = %fdata.ext

proc assetMetadata(f, dir: string): JsonNode = 
  result = newJObject()
  let fdata = f.splitFile
  let path = f.replace(dir & DirSep, "")
  result["path"] = %path
  result["type"] = %"asset"
  result["id"] = %path.changeFileExt("")
  result["ext"] = %fdata.ext

proc interpret(hs: HastySite, file: string) =
  var i = newMinInterpreter(file, file.parentDir)
  i.hastysite_module(hs)
  i.interpret(newFileStream(file, fmRead))

#### Main Functions

proc newHastySite*(file: string): HastySite = 
  let json = file.parseFile()
  result.settings = json
  result.dirs.assets = json.get("assets", "assets")
  result.dirs.contents = json.get("contents", "contents")
  result.dirs.templates = json.get("templates", "templates")
  result.dirs.output = json.get("output", "output")
  result.dirs.temp = json.get("temp", "temp")
  result.dirs.tempContents = result.dirs.temp / result.dirs.contents
  result.files.rules = json.get("rules", "rules.min")
  result.files.scripts = json.get("scripts", "scripts.min")
  result.files.metadata = result.dirs.temp / "metadata.json"

proc preprocess*(hs: var HastySite) = 
  var meta = newJObject()
  for f in hs.dirs.contents.walkDirRec():
    if f.isHidden:
      continue
    let content = f.preprocessContent(hs.dirs.contents & DirSep, meta)
    let dest = hs.dirs.temp/f
    dest.parentDir.createDir
    dest.writeFile(content)
  hs.files.metadata.writeFile(meta.pretty)
  hs.metadata = hs.files.metadata.parseFile
  let contents = toSeq(hs.dirs.tempContents.walkDirRec())
  let assets = toSeq(hs.dirs.assets.walkDirRec())
  let contentDir = hs.dirs.tempContents
  let assetDir = hs.dirs.assets
  hs.files.contents = contents.map(proc (f: string): JsonNode = return contentMetadata(f, contentDir, meta))
  hs.files.assets = assets.map(proc (f: string): JsonNode = return assetMetadata(f, assetDir))

proc init*(dir: string) =
  var json = newJObject()
  json["contents"]  = %"contents"
  json["assets"]    = %"assets"
  json["templates"]   = %"templates"
  json["temp"]      = %"temp"
  json["output"]    = %"output"
  for key, value in json.pairs:
    createDir(dir/value.getStr)
  json["title"]     = %"My Web Site"
  json["rules"]     = %"rules.min"
  json["scripts"]   = %"scripts.min"
  writeFile(dir/json["rules"].getStr, "")
  writeFile(dir/"settings.json", json.pretty)

proc clean*(hs: HastySite) =
  hs.dirs.temp.removeDir
  hs.dirs.output.removeDir

proc build*(hs: var HastySite) = 
  notice "Preprocessing..."
  hs.preprocess()
  notice "Processing rules..."
  hs.interpret(hs.files.rules)
  notice "All done."

when isMainModule:

  import
    parseopt2

  setLogFilter(lvlNotice)

  let usage = """  $1 v$2 - a tiny static site generator
  (c) 2016-2017 Fabio Cevasco
  
  Usage:
    hastysite command

  Commands:
    init              Initializes a new site in the current directory.
    build             Builds the site.
    clean             Cleans temporary files.
  Options:
    -h, --help        Print this help
    -v, --version     Print the program version""" % [appname, version]

  let pwd = getCurrentDir()
  let cfg = pwd/"settings.json"
  for kind, key, val in getopt():
    case kind:
      of cmdArgument:
        case key:
          of "init":
            pwd.init()
          of "clean":
            quitIfNotExists(cfg)
            var hs = newHastySite(cfg)
            hs.clean()
          of "build":
            quitIfNotExists(cfg)
            var hs = newHastySite(cfg)
            hs.clean()
            hs.build()
      of cmdLongOption, cmdShortOption:
        case key:
          of "help", "h":
            echo usage
            quit(0)
          of "version", "v":
            echo version
            quit(0)
          else:
            discard
      else:
        discard
