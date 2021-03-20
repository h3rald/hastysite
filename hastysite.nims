# https://blog.filippo.io/easy-windows-and-linux-cross-compilers-for-macos/

switch("amd64.windows.gcc.path", "/usr/local/bin")
switch("amd64.windows.gcc.exe", "x86_64-w64-mingw32-gcc")
switch("amd64.windows.gcc.linkerexe", "x86_64-w64-mingw32-gcc")

switch("amd64.linux.gcc.path", "/usr/local/bin")
switch("amd64.linux.gcc.exe", "x86_64-linux-musl-gcc")
switch("amd64.linux.gcc.linkerexe", "x86_64-linux-musl-gcc")

