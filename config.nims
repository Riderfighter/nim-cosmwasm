--os:linux
--cpu:i386
--threads:off
--cc:clang
--gc:arc
--noMain:on
--opt:size
--listCmd
--d:wasm
--stackTrace:off
--d:noSignalHandler
--exceptions:goto
--app:lib
--d:nimPreviewFloatRoundtrip # Avoid using sprintf as it's not available in wasm
--d:nimPages256

--nimcache:"nimcache"

--clang.exe:"/usr/bin/clang-15"  # Replace C
--clang.linkerexe:"/usr/bin/clang-15" # Replace C linker
--clang.cpp.exe:"/usr/bin/clang-15" # Replace C++
--clang.cpp.linkerexe:"/usr/bin/clang-15" # Replace C++ linker.

let llTarget = "wasm32-unknown-unknown-wasm"
switch("passC", "--target=" & llTarget)
switch("passL", "--target=" & llTarget)

switch("passC", "-I/usr/include") # Wouldn't compile without this :(

switch("passC", "-flto") # Important for code size!
switch("passC", "-fvisibility=hidden")
switch("passC", "-nostdlib")
switch("passC", "-fdata-sections")
switch("passC", "-ffunction-sections")
switch("passC", "-DPRINTF_DISABLE_SUPPORT_FLOAT=1")
switch("passC", "-DPRINTF_DISABLE_SUPPORT_LONG_LONG=1")
switch("passC", "-DPRINTF_DISABLE_SUPPORT_PTRDIFF_T=1")

# gc-sections seems to not have any effect
var 
    linkerOptions = "-nostdlib -Wl,--no-entry,--allow-undefined,--gc-sections,--strip-all,--error-limit=0,--lto-O3,-O3,--export=instantiate,--export=execute,--export=query,--export=interface_version_8,--export=allocate,--export=deallocate"

switch("clang.options.linker", linkerOptions)
switch("clang.cpp.options.linker", linkerOptions)
