--os:linux
--cpu:i386
--threads:off
--cc:clang
--gc:orc
--d:release
--nomain
--opt:size
--listCmd
--d:wasm
--stackTrace:off
--d:noSignalHandler
--exceptions:goto
# --app:lib
--d:nimPreviewFloatRoundtrip # Avoid using sprintf as it's not available in wasm
--d:nimPages256

--clang.exe:"/usr/bin/clang-15"  # Replace C
--clang.linkerexe:"/usr/bin/clang-15" # Replace C linker
--clang.cpp.exe:"/usr/bin/clang-15" # Replace C++
--clang.cpp.linkerexe:"/usr/bin/clang-15" # Replace C++ linker.

let llTarget = "wasm32-unknown-unknown-wasm"

switch("passC", "--target=" & llTarget)
switch("passL", "--target=" & llTarget)

switch("passC", "-I/usr/include") # Wouldn't compile without this :(

switch("passC", "-flto") # Important for code size!

# gc-sections seems to not have any effect
var linkerOptions = "-nostdlib -Wl,--no-entry,--allow-undefined,--export-dynamic,--gc-sections,--strip-all"

switch("clang.options.linker", linkerOptions)
switch("clang.cpp.options.linker", linkerOptions)
