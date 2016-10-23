import
  json,
  strutils,
  yaml,
  pegs,
  os,
  securehash,
  sequtils

import
  config

type
  HastySite* = object
    assets*: string
    contents*: string
    layouts*: string
    output*: string
    rules*: string
    temp*: string
    meta: string
    checksums: string
    tempContents: string
    modified: seq[string]
  NoMetadataException* = ref Exception


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
  stdout.write("Delete directory '$1' and all its contents? [Y/n] " % hs.temp)
  let confirm = stdin.readChar
  return confirm == 'Y' or confirm == 'y'

proc quitIfNotExists(file: string) = 
  if not file.fileExists:
    quit("Error: File '$1' not found." % file)

proc newHastySite*(file: string): HastySite = 
  let json = file.parseFile()
  result.assets = json.get("assets", "assets")
  result.contents = json.get("contents", "contents")
  result.layouts = json.get("layouts", "layouts")
  result.output = json.get("output", "output")
  result.rules = json.get("rules", "rules.min")
  result.temp = json.get("temp", "temp")
  result.meta = result.temp / "metadata.json"
  result.checksums = result.temp / "checksums.json"
  result.tempContents = result.temp / result.contents

proc preprocess*(hs: HastySite) = 
  var meta = newJObject()
  for f in hs.contents.walkDirRec():
    let content = f.preprocessFile(hs.contents & DirSep, meta)
    let dest = hs.temp/f
    dest.parentDir.createDir
    dest.writeFile(content)
  hs.meta.writeFile(meta.pretty)

proc detectChanges*(hs: var HastySite) = 
  hs.modified = newSeq[string](0)
  if not hs.checksums.fileExists:
    hs.checksums.writeFile("{}")
  var cs = hs.checksums.parseFile()
  let files = toSeq(hs.tempContents.walkDirRec())
  let dir = hs.tempContents
  hs.modified = filter(files) do (f: string) -> bool: f.checkFile(dir & DirSep, cs)
  hs.checksums.writeFile(cs.pretty)

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
  writeFile(dir/"config.json", json.pretty)

proc clean*(hs: HastySite) =
  hs.temp.removeDir

proc build*(hs: var HastySite) = 
  echo "Preprocessing..."
  hs.preprocess()
  hs.detectChanges()
  # TODO
  echo hs.modified

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
  let cfg = pwd/"config.json"
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
