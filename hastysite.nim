import
  json,
  strutils,
  yaml,
  pegs,
  os,
  securehash,
  sequtils,
  tables,
  critbits

import
  minim,
  vendor/moustachu,
  hastyscribe

import
  config

type
  HastyDirs = object
    assets*: string
    contents*: string
    layouts*: string
    output*: string
    temp*: string
    tempContents: string
  HastyFiles = object
    rules*: string
    metadata: string
    checksums: string
    modified: seq[string]
  HastySite* = object
    settings*: JsonNode
    dirs*: HastyDirs
    files*: HastyFiles 
    metadata*: JsonNode
  NoMetadataException* = ref Exception
  DictionaryRequiredException* = ref Exception


#### MiNiM Library

proc hastysite_module*(i: In, hs: HastySite) =
  i.define("hastysite")

    .symbol("metadata") do (i: In):
      i.push i.fromJson(hs.metadata)

    .symbol("settings") do (i: In):
      i.push i.fromJson(hs.settings)

    .symbol("modified") do (i: In):
      var modified = newSeq[MinValue](0)
      for s in hs.files.modified:
        modified.add s.newVal
      i.push modified.newVal(i.scope)

    .symbol("init-context") do (i: In):
      var d: MinValue
      i.reqDictionary d
      i.scope.symbols["context"] = MinOperator(val: d, kind: minValOp)

    .symbol("output") do (i: In):
      i.push hs.dirs.output.newVal

    .symbol("cget") do (i: In):
      var s, q: MinValue
      i.reqStringLike(s)
      i.apply(i.scope.getSymbol("context"))
      i.reqDictionary q
      i.push q.dget(s)

    .symbol("cset") do (i: In):
      var q, k: MinValue
      let m = i.pop
      i.reqStringLike k
      i.apply(i.scope.getSymbol("context"))
      i.reqDictionary q
      i.push i.dset(q, k, m) 

    .symbol("mustache") do (i: In):
      var t, c: MinValue
      i.reqQuotationAndString c, t
      if not c.isDictionary:
        raise DictionaryRequiredException(msg: "No dictionary provided as template context.")
      let ctx = newContext(%c)
      let tplname = t.getString & ".mustache"
      let tpl = readFile(hs.dirs.layouts/tplname)
      i.push tpl.render(ctx, hs.dirs.layouts).newval

    .symbol("markdown") do (i: In):
      var t, c: MinValue
      i.reqQuotationAndString c, t
      if not c.isDictionary:
        raise DictionaryRequiredException(msg: "No dictionary provided for markdown processor fields.")
      let options = HastyOptions(toc: false, output: nil, css: nil, watermark: nil, fragment: true)
      var fields = initTable[string, proc():string]()
      for items in c.qVal:
        fields[c.qVal[0].getString] = proc(): string = return $$c.qVal[1]
      var hastyscribe = newHastyScribe(options, fields)
      i.push hastyscribe.compileFragment(t.getString).newVal

    .finalize()
      
#### Helper Functions

proc preprocessFile(file, dir: string, obj: var JsonNode): string =
  let fileid = file.replace(dir, "")
  var f: File
  discard f.open(file)
  var s, yaml = ""
  result = ""
  var delimiter = 0
  while f.readLine(s):
    if delimiter >= 2:
      result &= s
    else:
      if s.match(peg"'-' '-' '-' '-'*"):
        delimiter.inc
      else:
        yaml &= "\n" & s
  if yaml == "":
    raise NoMetadataException(msg: "No metadata found in file: " & file)
  if not obj.hasKey("contents"):
    obj["contents"] = newJObject()
  obj["contents"][fileid] = yaml.loadToJson()[0]
  f.close()

proc checkFile(file, dir: string, obj: var JsonNode): bool =
  let fileid = file.replace(dir, "")
  if not obj.hasKey("contents"):
    obj["contents"] = newJObject()
  var oldChecksum = ""
  if obj["contents"].hasKey(fileid):
    oldChecksum = obj["contents"][fileid].getStr
  var newChecksum = $secureHashFile(file) 
  obj["contents"][fileid] = %newChecksum
  return oldChecksum != newChecksum

proc get(json: JsonNode, key, default: string): string =
  if json.hasKey(key):
    return json[key].getStr
  else:
    return default

proc confirmClean(hs: HastySite): bool =
  stdout.write("Delete directory '$1' and all its contents? [Y/n] " % hs.dirs.temp)
  let confirm = stdin.readChar
  return confirm == 'Y' or confirm == 'y'

proc quitIfNotExists(file: string) = 
  if not file.fileExists:
    quit("Error: File '$1' not found." % file)

#### Main Functions

proc newHastySite*(file: string): HastySite = 
  let json = file.parseFile()
  result.settings = json
  result.dirs.assets = json.get("assets", "assets")
  result.dirs.contents = json.get("contents", "contents")
  result.dirs.layouts = json.get("layouts", "layouts")
  result.dirs.output = json.get("output", "output")
  result.dirs.temp = json.get("temp", "temp")
  result.dirs.tempContents = result.dirs.temp / result.dirs.contents
  result.files.rules = json.get("rules", "rules.min")
  result.files.metadata = result.dirs.temp / "metadata.json"
  result.files.checksums = result.dirs.temp / "checksums.json"

proc preprocess*(hs: HastySite) = 
  var meta = newJObject()
  for f in hs.dirs.contents.walkDirRec():
    let content = f.preprocessFile(hs.dirs.contents & DirSep, meta)
    let dest = hs.dirs.temp/f
    dest.parentDir.createDir
    dest.writeFile(content)
  hs.files.metadata.writeFile(meta.pretty)

proc detectChanges*(hs: var HastySite) = 
  hs.files.modified = newSeq[string](0)
  if not hs.files.checksums.fileExists:
    hs.files.checksums.writeFile("{}")
  var cs = hs.files.checksums.parseFile()
  let files = toSeq(hs.dirs.tempContents.walkDirRec())
  let dir = hs.dirs.tempContents
  hs.files.modified = filter(files) do (f: string) -> bool: f.checkFile(dir & DirSep, cs)
  hs.files.checksums.writeFile(cs.pretty)

proc init*(dir: string) =
  var json = newJObject()
  json["contents"]  = %"contents"
  json["assets"]    = %"assets"
  json["layouts"]   = %"layouts"
  json["temp"]      = %"temp"
  json["output"]    = %"output"
  for key, value in json.pairs:
    createDir(dir/value.getStr)
  json["title"]     = %"My Web Site"
  json["rules"]     = %"rules.min"
  writeFile(dir/json["rules"].getStr, "")
  writeFile(dir/"settings.json", json.pretty)

proc clean*(hs: HastySite) =
  hs.dirs.temp.removeDir

proc build*(hs: var HastySite) = 
  echo "Preprocessing..."
  hs.preprocess()
  hs.detectChanges()
  # TODO
  echo hs.files.modified


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
      if hs.confirmClean():
        hs.clean()
      else:
        quit("Aborted.")
    of "rebuild":
      quitIfNotExists(cfg)
      var hs = newHastySite(cfg)
      if hs.confirmClean():
        hs.clean()
        hs.build()
      else:
        quit("Aborted.")
    else:
      quit("Error: Command '$1' is not supported" % command)
