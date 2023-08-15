import hastysitepkg/config

# Package
version       = pkgVersion
author        = pkgAuthor
description   = pkgDescription
license       = "MIT"
bin           = @["hastysite"]
installDirs   = @["minpkg", "hastysitepkg"]

# Deps
requires: "nim >= 2.0.0, min >= 0.39.1, checksums"

before install:
  exec "nimble install -y nifty"
  exec "nifty remove -f"
  exec "nifty install"
  exex "nifty build discount"

# Tasks
const
  compile = "nim c -d:release"
  linux_x64 = "--cpu:amd64 --os:linux"
  windows_x64 = "--cpu:amd64 --os:windows"
  macosx_x64 = ""
  #parallel = "--parallelBuild:1 --verbosity:3"
  hs = "hastysite"
  hs_file = "hastysite.nim"
  zip = "zip -X"

proc shell(command, args: string, dest = "") =
  exec command & " " & args & " " & dest

proc filename_for(os: string, arch: string): string =
  return "hastysite" & "_v" & version & "_" & os & "_" & arch & ".zip"

task windows_x64_build, "Build hastysite for Windows (x64)":
  shell compile, windows_x64, hs_file

task linux_x64_build, "Build hastysite for Linux (x64)":
  shell compile, linux_x64,  hs_file
  
task macosx_x64_build, "Build hastysite for Mac OS X (x64)":
  shell compile, macosx_x64, hs_file

task release, "Release hastysite":
  echo "\n\n\n WINDOWS - x64:\n\n"
  windows_x64_buildTask()
  shell zip, filename_for("windows", "x64"), hs & ".exe"
  shell "rm", hs & ".exe"
  echo "\n\n\n LINUX - x64:\n\n"
  linux_x64_buildTask()
  shell zip, filename_for("linux", "x64"), hs 
  shell "rm", hs 
  echo "\n\n\n MAC OS X - x64:\n\n"
  macosx_x64_buildTask()
  shell zip, filename_for("macosx", "x64"), hs 
  shell "rm", hs 
  echo "\n\n\n ALL DONE!"
