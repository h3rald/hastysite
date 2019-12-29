import
  json,
  strutils,
  os,
  sequtils,
  tables,
  critbits,
  streams,
  parsecfg,
  logging,
  pegs

{.passL: "-Lpackages/hastyscribe/src/hastyscribepkg/vendor".}
when defined(linux):
  {.passL:"-static".}

import
  packages/min/min,
  packages/min/packages/sha1/sha1,
  packages/min/packages/niftylogger,
  packages/hastyscribe/src/hastyscribe,
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
    scripts*: string
  HastyFiles = object
    rules*: string
    checksums: string
    contents: seq[JsonNode]
    assets: seq[JsonNode]
  HastySite* = object
    settings*: JsonNode
    checksums*: JsonNode
    scripts*: JsonNode
    dirs*: HastyDirs
    files*: HastyFiles 
  NoMetadataException* = ref Exception
  DictionaryRequiredException* = ref Exception
  MetadataRequiredException* = ref Exception

const SCRIPT_BUILD = "./site/scripts/build.min".slurp
const SCRIPT_CLEAN = "./site/scripts/clean.min".slurp
const SCRIPT_POST = "./site/scripts/post.min".slurp
const SCRIPT_PAGE = "./site/scripts/page.min".slurp
const TEMPLATE_HEAD = "./site/templates/_head.mustache".slurp
const TEMPLATE_HEADER = "./site/templates/_header.mustache".slurp
const TEMPLATE_FOOTER = "./site/templates/_footer.mustache".slurp
const TEMPLATE_NEWS = "./site/templates/news.mustache".slurp
const TEMPLATE_PAGE = "./site/templates/page.mustache".slurp
const TEMPLATE_post = "./site/templates/post.mustache".slurp
const FONT_SCP_R = "./site/assets/fonts/SourceCodePro-Regular.woff".slurp
const FONT_SCP_I = "./site/assets/fonts/SourceCodePro-It.woff".slurp
const FONT_SCP_B = "./site/assets/fonts/SourceCodePro-Bold.woff".slurp
const FONT_SCP_BI = "./site/assets/fonts/SourceCodePro-BoldIt.woff".slurp
const FONT_SSP_R = "./site/assets/fonts/SourceSansPro-Light.woff".slurp
const FONT_SSP_I = "./site/assets/fonts/SourceSansPro-LightIt.woff".slurp
const FONT_SSP_B = "./site/assets/fonts/SourceSansPro-Semibold.woff".slurp
const FONT_SSP_BI = "./site/assets/fonts/SourceSansPro-SemiboldIt.woff".slurp
const FONT_FAS = "./site/assets/fonts/fa-solid-900.woff".slurp
const FONT_FAB = "./site/assets/fonts/fa-brands-400.woff".slurp
const STYLE_FONTS = "./site/assets/styles/fonts.css".slurp
const STYLE_HASTYSITE = "./site/assets/styles/hastysite.css".slurp
const STYLE_HASTYSCRIBE = "./site/assets/styles/hastyscribe.css".slurp
const STYLE_LUXBAR = "./site/assets/styles/luxbar.css".slurp
const STYLE_SITE = "./site/assets/styles/site.css".slurp
const RULES = "./site/rules.min".slurp

let PEG_CSS_VAR_DEF = peg"""'--' {[a-zA-Z0-9_-]+} ':' {@} ';'"""
let PEG_CSS_VAR_INSTANCE = peg"""
  instance <- 'var(--' {id} ')'
  id <- [a-zA-Z0-9_-]+
  """
let PEG_CSS_IMPORT = peg"""
  import <- '@import' \s+ '\'' {partial} '\';'
  partial <- [a-zA-Z0-9_-]+
"""

var CSS_VARS = initTable[string, string]()

#### Helper Functions

proc processCssVariables(text: string): string =
  result = text
  for def in result.findAll(PEG_CSS_VAR_DEF):
    var matches: array[0..1, string]
    discard def.match(PEG_CSS_VAR_DEF, matches)
    let id = matches[0].strip
    let value = matches[1].strip
    CSS_VARS[id] = value
  for instance in result.findAll(PEG_CSS_VAR_INSTANCE):
    var matches: array[0..1, string]
    discard instance.match(PEG_CSS_VAR_INSTANCE, matches)
    let id = matches[0].strip
    if CSS_VARS.hasKey(id):
      result = result.replace(instance, CSS_VARS[id])
    else:
      stderr.writeLine("CSS variable '$1' is not defined." % ["--" & id])

proc processCssImportPartials(text: string, hs: HastySite): string = 
  result = text
  var folder = "assets/styles"
  if hs.settings.hasKey("css-partials"):
    folder = hs.settings["css-partials"].getStr
  for def in result.findAll(PEG_CSS_IMPORT):
    var matches: array[0..1, string]
    discard def.match(PEG_CSS_IMPORT, matches)
    let partial  = folder/"_" & matches[0].strip & ".css"
    var contents = ""
    if partial.existsFile:
      contents = partial.readFile
      result = result.replace(def, contents)
    else:
      stderr.writeLine("@import: partial '$1' does not exist" % [partial])

proc preprocessContent(file, dir: string, obj: var JsonNode): string =
  let fileid = file.replace(dir, "")
  var f: File
  discard f.open(file)
  var s, cfg = ""
  result = ""
  var delimiter = 0
  try:
    while f.readLine(s):
      if delimiter >= 2:
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

proc contentMetadata(f, dir: string, meta: JsonNode): JsonNode = 
  result = newJObject()
  let fdata = f.splitFile
  let path = f.replace(dir & DirSep, "")
  if meta.hasKey("contents") and meta["contents"].hasKey(path):
    for key, value in meta["contents"][path].pairs:
      result[key] = value
  result["path"] = %path                    # source path relative to input
  result["type"] = %"content"             
  result["ext"] = %fdata.ext                # output extension
  if fdata.ext == "":
    result["id"] = %path
  else:
    result["id"] = %path.changeFileExt("")  # output path relative to output without extension

proc assetMetadata(f, dir: string): JsonNode = 
  result = newJObject()
  let fdata = f.splitFile
  let path = f.replace(dir & DirSep, "")
  result["path"] = %path                    # source path relative to input
  result["type"] = %"asset"               
  result["ext"] = %fdata.ext                # output extension
  if fdata.ext == "":
    result["id"] = %path
  else:
    result["id"] = %path.changeFileExt("")  # output path relative to output without extension

proc hastysite_module*(i: In, hs1: HastySite)

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
  result.dirs.scripts = json.get("scripts", "scripts")
  result.files.rules = json.get("rules", "rules.min")
  result.files.checksums = result.dirs.temp / "checksums.json"
  result.scripts = newJObject()
  for f in result.dirs.scripts.walkDir(true):
    let path = result.dirs.scripts/f.path
    let file = path.open()
    let desc = file.readLine.replace(";", "")
    let key = f.path.replace(".min", "")
    file.close()
    result.scripts[key] = %desc

proc preprocess*(hs: var HastySite) = 
  if hs.dirs.tempContents.existsDir:
    hs.dirs.tempContents.removeDir
  var meta = newJObject()
  for f in hs.dirs.contents.walkDirRec():
    if f.isHidden:
      continue
    info("Preprocessing: " & f);
    let content = f.preprocessContent(hs.dirs.contents & DirSep, meta)
    let dest = hs.dirs.temp/f
    dest.parentDir.createDir
    dest.writeFile(content)
  if not hs.dirs.temp.dirExists:
    hs.dirs.temp.createDir
  if not hs.files.checksums.fileExists:
    let checksums = newJObject()
    hs.files.checksums.writeFile(checksums.pretty)
  hs.checksums = hs.files.checksums.parseFile
  let contents = toSeq(hs.dirs.tempContents.walkDirRec())
  let assets = toSeq(hs.dirs.assets.walkDirRec())
  let contentDir = hs.dirs.tempContents
  let assetDir = hs.dirs.assets
  hs.files.contents = contents.map(proc (f: string): JsonNode = return contentMetadata(f, contentDir, meta))
  info("Total Contents: " & $hs.files.contents.len)
  hs.files.assets = assets.map(proc (f: string): JsonNode = return assetMetadata(f, assetDir))
  info("Total Assets: " & $hs.files.assets.len)

proc init*(dir: string) =
  var json = newJObject()
  json["contents"]  = %"contents"
  json["assets"]    = %"assets"
  json["templates"]   = %"templates"
  json["temp"]      = %"temp"
  json["output"]    = %"output"
  json["scripts"]   = %"scripts"
  json["css-partials"] = %"assets/styles"
  for key, value in json.pairs:
    createDir(dir/value.getStr)
  createDir(dir/"assets/fonts")
  createDir(dir/"assets/styles")
  json["title"]     = %"My Web Site"
  json["rules"]     = %"rules.min"
  writeFile(dir/"rules.min", RULES)
  writeFile(dir/"settings.json", json.pretty)
  writeFile(dir/"scripts/build.min", SCRIPT_BUILD)
  writeFile(dir/"scripts/clean.min", SCRIPT_CLEAN)
  writeFile(dir/"scripts/page.min", SCRIPT_PAGE)
  writeFile(dir/"scripts/clean.min", SCRIPT_POST)
  writeFile(dir/"templates/_head.mustache", TEMPLATE_HEAD)
  writeFile(dir/"templates/_header.mustache", TEMPLATE_HEADER)
  writeFile(dir/"templates/_footer.mustache", TEMPLATE_FOOTER)
  writeFile(dir/"templates/page.mustache", TEMPLATE_PAGE)
  writeFile(dir/"templates/news.mustache", TEMPLATE_NEWS)
  writeFile(dir/"templates/post.mustache", TEMPLATE_POST)
  writeFile(dir/"assets/fonts/SourceCodePro-Regular.woff", FONT_SCP_R)
  writeFile(dir/"assets/fonts/SourceCodePro-It.woff", FONT_SCP_I)
  writeFile(dir/"assets/fonts/SourceCodePro-Bold.woff", FONT_SCP_B)
  writeFile(dir/"assets/fonts/SourceCodePro-BoldIt.woff", FONT_SCP_BI)
  writeFile(dir/"assets/fonts/SourceSansPro-Light.woff", FONT_SSP_R)
  writeFile(dir/"assets/fonts/SourceSansPro-Semibold.woff", FONT_SSP_B)
  writeFile(dir/"assets/fonts/SourceSansPro-LightIt.woff", FONT_SSP_I)
  writeFile(dir/"assets/fonts/SourceSansPro-SemiboldIt.woff", FONT_SSP_BI)
  writeFile(dir/"assets/fonts/fa-solid-900.woff", FONT_FAS)
  writeFile(dir/"assets/fonts/fa-brands-400.woff", FONT_FAB)
  writeFile(dir/"assets/styles/fonts.css", STYLE_FONTS)
  writeFile(dir/"assets/styles/hastyscribe.css", STYLE_HASTYSCRIBE)
  writeFile(dir/"assets/styles/hastysite.css", STYLE_HASTYSITE)
  writeFile(dir/"assets/styles/luxbar.css", STYLE_LUXBAR)
  writeFile(dir/"assets/styles/site.css", STYLE_SITE)

proc wasModified(hs: HastySite, sha1: string, outfile: string): bool =
  return (not hs.checksums.hasKey(outfile) or hs.checksums[outfile] != %sha1)

proc updateSHA1(hs: HastySite, sha1: string, outfile: string) =
  hs.checksums[outfile] = %sha1

proc postprocess(hs: HastySite) =
  hs.files.checksums.writeFile(hs.checksums.pretty)

#### min Library

proc hastysite_module*(i: In, hs1: HastySite) =
  var hs = hs1
  let def = i.define()
  
  def.symbol("preprocess") do (i: In):
    hs.preprocess()

  def.symbol("postprocess") do (i: In):
    hs.postprocess()

  def.symbol("process-rules") do (i: In):
    hs.interpret(hs.files.rules)

  def.symbol("clean-output") do (i: In): 
    hs.dirs.output.removeDir

  def.symbol("clean-temp") do (i: In): 
    hs.dirs.temp.removeDir

  def.symbol("settings") do (i: In):
    i.push i.fromJson(hs.settings)

  def.symbol("contents") do (i: In):
    var contents = newSeq[MinValue](0)
    debug("JSON Contents requested")
    for j in hs.files.contents:
      debug(j)
      contents.add i.fromJson(j)
    i.push contents.newVal()

  def.symbol("assets") do (i: In):
    var assets = newSeq[MinValue](0)
    for j in hs.files.assets:
      assets.add i.fromJson(j)
    i.push assets.newVal()

  def.symbol("output") do (i: In):
    i.push hs.dirs.output.newVal

  def.symbol("input-fread") do (i: In):
    var vals = i.expect(["dict"])
    var d = vals[0]
    let t = i.dget(d, "type").getString 
    let path = i.dget(d, "path").getString
    var contents = ""
    if t == "content":
      contents = readFile(hs.dirs.tempContents/path)
    else:
      contents = readFile(hs.dirs.assets/path)
    i.push contents.newVal

  def.symbol("output-fwrite") do (i: In):
    var vals = i.expect(["dict"])
    var d = vals[0]
    let id = i.dget(d, "id").getString
    let ext = i.dget(d, "ext").getString
    var contents = ""
    try:
      contents = i.dget(d, "contents").getString
    except:
      raise MetadataRequiredException(msg: "Metadata key 'contents' not found in dictionary.")
    let outname = id&ext
    let outfile = hs.dirs.output/outname
    outfile.parentDir.createDir
    let sha1 = compute(contents).toHex
    if hs.wasModified(sha1, outname):
      notice " - Writing file: ", outfile
      hs.updateSHA1(sha1, outname)
      writeFile(outfile, contents)

  def.symbol("output-cp") do (i: In):
    var vals = i.expect(["dict"])
    var d = vals[0]
    let t = i.dget(d, "type").getString 
    let path = i.dget(d, "path").getString
    let id = i.dget(d, "id").getString
    let ext = i.dget(d, "ext").getString
    var infile, outfile: string
    let outname = id&ext
    if t == "content":
      infile = hs.dirs.tempContents/path
      outfile = hs.dirs.output/outname
    else:
      infile = hs.dirs.assets/path
      outfile = hs.dirs.output/outname
    let sha1 = compute(infile.readFile).toHex
    if hs.wasModified(sha1, outname):
      hs.updateSHA1(sha1, outname)
      notice " - Copying: ", infile, " -> ", outfile
      outfile.parentDir.createDir
      copyFileWithPermissions(infile, outfile)

  def.symbol("preprocess-css") do (i: In):
    var vals = i.expect("string")
    let css = vals[0]
    var res = css.getString.processCssImportPartials(hs)
    res = res.processCssVariables()
    i.push res.newVal()

  def.symbol("mustache") do (i: In):
    var vals = i.expect(["dict", "string"])
    let c = vals[0]
    let t = vals[1]
    let ctx = newContext(i%c)
    let tplname = t.getString & ".mustache"
    let tpl = readFile(hs.dirs.templates/tplname)
    i.push tpl.render(ctx, hs.dirs.templates).newval

  def.symbol("markdown") do (i: In):
    var vals = i.expect(["dict", "string"])
    let c = vals[0]
    let t = vals[1]
    let options = HastyOptions(toc: false, output: "", css: "", watermark: "", fragment: true)
    var fields = initTable[string, proc():string]()
    for key, v in c.dVal:
      closureScope:
        let key_closure = key
        let val_closure = $$v.val
        fields[key_closure] = proc(): string = 
          return val_closure
    var hastyscribe = newHastyScribe(options, fields)
    let file = t.getString()
    i.push hastyscribe.compileFragment(file, hs.dirs.contents).newVal

  def.finalize("hastysite")
      

when isMainModule:

  import
    parseopt
    
  if logging.getHandlers().len == 0:
    newNiftyLogger().addHandler()
  setLogFilter(lvlNotice)

  proc usage(scripts: bool, hs: HastySite): string = 
    var text = """  $1 v$2 - a tiny static site generator
  (c) 2016-2018 Fabio Cevasco
  
  Usage:
    hastysite command

  Commands:
    init - Initializes a new site in the current directory.
""" % [pkgName, pkgVersion]
    if scripts:
      for key, value in hs.scripts.pairs:
        text &= "    " & key & " - " & value.getStr & "\n"
    text &= """  Options:
    -h, --help        Print this help
    -l, --loglevel    Sets the log level (one of: debug, info, notice,
                      warn, error, fatal). Default: notice
    -v, --version     Print the program version""" 
    return text

  let pwd = getCurrentDir()
  let cfg = pwd/"settings.json"
  var hs: HastySite
  var scripts = false

  if cfg.fileExists:
    hs = newHastySite(cfg)
    scripts = true

  for kind, key, val in getopt():
    case kind:
      of cmdArgument:
        case key:
          of "init":
            pwd.init()
          else:
            if scripts:
              if hs.scripts.hasKey(key):
                hs.interpret(hs.dirs.scripts/key & ".min")
              else:
                fatal "Script '$1' not found" % key
            else:
              fatal "This directory does not contain a valid HastySite site"
      of cmdLongOption, cmdShortOption:
        case key:
          of "loglevel", "l":
            var v = val
            setLogLevel(v)
          of "help", "h":
            echo usage(scripts, hs)
            quit(0)
          of "version", "v":
            echo pkgVersion
            quit(0)
          else:
            discard
      else:
        discard
