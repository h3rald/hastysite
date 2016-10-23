import
  os,
  parsecfg,
  streams,
  strutils

const
  cfgfile   = "hastysite.nimble".slurp

var
  appname*  = "HastySite"
  version*: string
  f = newStringStream(cfgfile)

if f != nil:
  var p: CfgParser
  open(p, f, "hastysite.nimble")
  while true:
    var e = next(p)
    case e.kind
    of cfgEof:
      break
    of cfgKeyValuePair:
      case e.key:
        of "version":
          version = e.value
        else:
          discard
    of cfgError:
      stderr.writeLine("Configuration error.")
      quit(1)
    else: 
      discard
  close(p)
else:
  stderr.writeLine("Cannot process configuration file.")
  quit(2)
