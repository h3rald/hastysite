import
  json,
  strutils,
  pegs,
  os,
  securehash,
  sequtils,
  tables,
  critbits,
  streams,
  logging

when defined(nifty):
  import 
    packages/NimYAML/yaml,
    packages/minim/minim,
    packages/hastyscribe/hastyscribe
else:
  import
    yaml,
    minim,
    hastyscribe

import
  vendor/moustachu,
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
    checksums: string
    modified: seq[JsonNode]
  HastySite* = object
    settings*: JsonNode
    metadata*: JsonNode
    dirs*: HastyDirs
    files*: HastyFiles 
  NoMetadataException* = ref Exception
  DictionaryRequiredException* = ref Exception
  MetadataRequiredException* = ref Exception

setLogFilter(lvlNotice)

#### MiNiM Library

proc hastysite_module*(i: In, hs: HastySite) =
  i.define("hastysite")

    .symbol("metadata") do (i: In):
      i.push i.fromJson(hs.metadata)

    .symbol("settings") do (i: In):
      i.push i.fromJson(hs.settings)

    .symbol("modified") do (i: In):
      var modified = newSeq[MinValue](0)
      for j in hs.files.modified:
        modified.add i.fromJson(j)
      i.push modified.newVal(i.scope)

    .symbol("output") do (i: In):
      i.push hs.dirs.output.newVal

    .symbol("input-fread") do (i: In):
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

    .symbol("output-fwrite") do (i: In):
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

    .symbol("copy2output") do (i: In):
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

    .symbol("content?") do (i: In):
      var d: MinValue
      i.reqDictionary d
      let t = d.dget("type".newVal).getString 
      let r = t == "content"
      i.push r.newVal

    .symbol("asset?") do (i: In):
      var d: MinValue
      i.reqDictionary d
      let t = d.dget("type".newVal).getString 
      let r = t == "asset"
      i.push r.newVal

    .symbol("mustache") do (i: In):
      var t, c: MinValue
      i.reqQuotationAndString c, t
      if not c.isDictionary:
        raise DictionaryRequiredException(msg: "No dictionary provided as template context.")
      let ctx = newContext(%c)
      let tplname = t.getString & ".mustache"
      let tpl = readFile(hs.dirs.templates/tplname)
      i.push tpl.render(ctx, hs.dirs.templates).newval

    .symbol("markdown") do (i: In):
      var t, c: MinValue
      i.reqQuotationAndString c, t
      if not c.isDictionary:
        raise DictionaryRequiredException(msg: "No dictionary provided for markdown processor fields.")
      let options = HastyOptions(toc: false, output: nil, css: nil, watermark: nil, fragment: true)
      var fields = initTable[string, proc():string]()
      for item in c.qVal:
        fields[item.qVal[0].getString] = proc(): string = return $$item.qVal[1]
      var hastyscribe = newHastyScribe(options, fields)
      i.push hastyscribe.compileFragment(t.getString).newVal

    .finalize()
      
#### Helper Functions

proc preprocessContent(file, dir: string, obj: var JsonNode): string =
  let fileid = file.replace(dir, "")
  var f: File
  discard f.open(file)
  var s, yaml = ""
  result = ""
  var delimiter = 0
  while f.readLine(s):
    if delimiter >= 2:
      result &= s&"\n"
    else:
      if s.match(peg"'-' '-' '-' '-'*"):
        delimiter.inc
      else:
        yaml &= s&"\n"
  if yaml == "":
    raise NoMetadataException(msg: "No metadata found in file: " & file)
  if not obj.hasKey("contents"):
    obj["contents"] = newJObject()
  var meta = yaml.loadToJson()[0]
  meta["path"] = %fileid
  meta["type"] = %"content"
  meta["id"] = %fileid.changeFileExt("")
  meta["ext"] = %fileid.splitFile.ext
  obj["contents"][fileid] = meta
  f.close()

proc checkContent(dir, file: string, obj: var JsonNode): bool =
  var dir = dir & DirSep
  let fileid = file.replace(dir, "")
  var oldChecksum = ""
  if obj["contents"].hasKey(fileid):
    oldChecksum = obj["contents"][fileid].getStr
  var newChecksum = $secureHashFile(file) 
  obj["contents"][fileid] = %newChecksum
  return oldChecksum != newChecksum

proc checkAsset(dir, file: string, obj: var JsonNode): bool =
  var dir = dir & DirSep
  let fileid = file.replace(dir, "")
  var oldChecksum = ""
  if obj["assets"].hasKey(fileid):
    oldChecksum = obj["assets"][fileid].getStr
  var newChecksum = $secureHashFile(file) 
  obj["assets"][fileid] = %newChecksum
  return oldChecksum != newChecksum

proc get(json: JsonNode, key, default: string): string =
  if json.hasKey(key):
    return json[key].getStr
  else:
    return default

proc confirmDeleteDir(hs: HastySite, dir: string): bool =
  warn "Delete directory '$1' and all its contents? [Y/n] " % dir
  let confirm = $stdin.readChar
  return confirm == "\n" or confirm == "Y" or confirm == "y"

proc quitIfNotExists(file: string) = 
  if not file.fileExists:
    quit("Error: File '$1' not found." % file)

proc initChecksums(hs: HastySite): JsonNode = 
  if not hs.files.checksums.fileExists:
    hs.files.checksums.writeFile("{}")
  result = hs.files.checksums.parseFile()
  if not result.hasKey("contents"):
    result["contents"] = newJObject()
  if not result.hasKey("assets"):
    result["assets"] = newJObject()

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
  result.files.checksums = result.dirs.temp / "checksums.json"

proc preprocess*(hs: HastySite) = 
  var meta = newJObject()
  for f in hs.dirs.contents.walkDirRec():
    let content = f.preprocessContent(hs.dirs.contents & DirSep, meta)
    let dest = hs.dirs.temp/f
    dest.parentDir.createDir
    dest.writeFile(content)
  hs.files.metadata.writeFile(meta.pretty)

proc detectChanges*(hs: var HastySite) = 
  hs.files.modified = newSeq[JsonNode](0)
  var cs = hs.initChecksums()
  let contents = toSeq(hs.dirs.tempContents.walkDirRec())
  let assets = toSeq(hs.dirs.assets.walkDirRec())
  let assetDir = hs.dirs.assets
  let contentDir = hs.dirs.tempContents
  hs.metadata = hs.files.metadata.parseFile
  let meta = hs.metadata
  let modContentFiles = filter(contents) do (f: string) -> bool: checkContent(contentDir, f, cs)
  let modAssetFiles = filter(assets) do (f: string) -> bool: checkAsset(assetDir, f, cs)
  let modContents = modContentFiles.map(proc (f: string): JsonNode = return contentMetadata(f, contentDir, meta))
  let modAssets = modAssetFiles.map(proc (f: string): JsonNode = return assetMetadata(f, assetDir))
  hs.files.modified = modContents & modAssets
  hs.files.checksums.writeFile(cs.pretty)

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

proc build*(hs: var HastySite) = 
  notice "Preprocessing..."
  hs.preprocess()
  notice "Detecting changes..."
  hs.detectChanges()
  notice "Processing rules..."
  hs.interpret(hs.files.rules)
  notice "All done."

when isMainModule:

  import
    vendor/commandeer

  proc usage(): string =
    return """  $1 v$2 - a tiny static site generator
  (c) 2016 Fabio Cevasco
  
  Usage:
    hastysite command

  Commands:
    init              Initializes a new site in the current directory.
    build             Builds the site.
    clean             Cleans temporary file.
    rebuild           Rebuilds the site, after cleaning temporary files.
  Options:
    -h, --help        Print this help
    -v, --version     Print the program version""" % [appname, version]



  commandline:
    argument command, string
    exitoption "help", "h", usage()
    exitoption "version", "v", version
    errormsg usage()

  let pwd = getCurrentDir()
  let cfg = pwd/"settings.json"
  case command:
    of "init":
      pwd.init()
    of "build":
      quitIfNotExists(cfg)
      var hs = newHastySite(cfg)
      hs.build()
    of "clean":
      quitIfNotExists(cfg)
      var hs = newHastySite(cfg)
      if hs.confirmDeleteDir(hs.dirs.temp) and hs.confirmDeleteDir(hs.dirs.output):
        hs.clean()
      else:
        quit("Aborted.")
    of "rebuild":
      quitIfNotExists(cfg)
      var hs = newHastySite(cfg)
      #if hs.confirmDeleteDir(hs.dirs.temp) and hs.confirmDeleteDir(hs.dirs.output):
      hs.clean()
      hs.build()
      #else:
      #  quit("Aborted.")
    else:
      quit("Error: Command '$1' is not supported" % command)
