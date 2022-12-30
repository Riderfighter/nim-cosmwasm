import macros
import wasmrt/minify

proc stripSinkFromArgType(t: NimNode): NimNode =
  result = t
  if result.kind == nnkBracketExpr and result.len == 2 and result[0].kind == nnkSym and $result[0] == "sink":
    result = result[1]

iterator arguments(formalParams: NimNode): tuple[idx: int, name, typ, default: NimNode] =
  formalParams.expectKind(nnkFormalParams)
  var iParam = 0
  for i in 1 ..< formalParams.len:
    let pp = formalParams[i]
    for j in 0 .. pp.len - 3:
      yield (iParam, pp[j], copyNimTree(stripSinkFromArgType(pp[^2])), pp[^1])
      inc iParam

macro exportwasm*(p: untyped): untyped =
  expectKind(p, nnkProcDef)
  result = p
  result.addPragma(newIdentNode("exportc"))
  let cgenDecl = when defined(cpp):
                   "extern \"C\" __attribute__ ((visibility (\"default\"))) $# $#$#"
                 else:
                   "__attribute__ ((visibility (\"default\"))) $# $#$#"

  result.addPragma(newColonExpr(newIdentNode("codegenDecl"), newLit(cgenDecl)))


{.emit: """
int stdout = 0;
int stderr = 1;
static int dummyErrno = 0;

N_LIB_PRIVATE void* memcpy(void* a, const void* b, size_t s) {
  char* aa = (char*)a;
  char* bb = (char*)b;
  while(s) {
    --s;
    *aa = *bb;
    ++aa;
    ++bb;
  }
  return a;
}

N_LIB_PRIVATE void* memmove(void *dest, const void *src, size_t len) { /* Copied from https://code.woboq.org/gcc/libgcc/memmove.c.html */
  char *d = dest;
  const char *s = src;
  if (d < s)
    while (len--)
      *d++ = *s++;
  else {
    char *lasts = s + (len-1);
    char *lastd = d + (len-1);
    while (len--)
      *lastd-- = *lasts--;
  }
  return dest;
}

N_LIB_PRIVATE void* memchr(register const void* src_void, int c, size_t length) { /* Copied from https://code.woboq.org/gcc/libiberty/memchr.c.html */
  const unsigned char *src = (const unsigned char *)src_void;

  while (length-- > 0) {
    if (*src == c)
     return (void*)src;
    src++;
  }
  return NULL;
}

N_LIB_PRIVATE int memcmp(const void* a, const void* b, size_t s) {
  char* aa = (char*)a;
  char* bb = (char*)b;
  if (aa == bb) return 0;

  while(s) {
    --s;
    int ia = *aa;
    int ib = *bb;
    int r = ia - ib; // TODO: The result might be inverted. Verify against C standard.
    if (r) return r;
    *aa = *bb;
    ++aa;
    ++bb;
  }
  return 0;
}

N_LIB_PRIVATE void* memset(void* a, int b, size_t s) {
  char* aa = (char*)a;
  while(s) {
    --s;
    *aa = b;
    ++aa;
  }
  return a;
}

N_LIB_PRIVATE size_t strlen(const char* a) {
  const char* b = a;
  while (*b++);
  return b - a - 1;
}

N_LIB_PRIVATE char* strerror(int errnum) {
  return "strerror is not supported";
}

N_LIB_PRIVATE int* __errno_location() {
  return &dummyErrno;
}

N_LIB_PRIVATE char* strstr(char *haystack, const char *needle) {
  if (haystack == NULL || needle == NULL) {
    return NULL;
  }

  for ( ; *haystack; haystack++) {
    // Is the needle at this point in the haystack?
    const char *h, *n;
    for (h = haystack, n = needle; *h && *n && (*h == *n); ++h, ++n) {
      // Match is progressing
    }
    if (*n == '\0') {
      // Found match!
      return haystack;
    }
    // Didn't match here.  Try again further along haystack.
  }
  return NULL;
}
""".}
const wasmPageSize = 64 * 1024
proc wasmMemorySize(i: int32): int32 {.importc: "__builtin_wasm_memory_size", nodecl.}
proc wasmMemoryGrow(b: int32): int32 {.inline.} =
  when true:
    proc int_wasm_memory_grow(m, b: int32) {.importc: "__builtin_wasm_memory_grow", nodecl.}
    int_wasm_memory_grow(0, b)
  else:
    proc int_wasm_memory_grow(b: int32) {.importc: "__builtin_wasm_grow_memory", nodecl.}
    int_wasm_memory_grow(b)

var memStart, totalMemory: uint

proc wasmAlloc(block_size: uint): pointer {.inline.} =
  if totalMemory == 0:
    totalMemory = cast[uint](wasmMemorySize(0)) * wasmPageSize
    memStart = totalMemory

  result = cast[pointer](memStart)

  let availableMemory = totalMemory - memStart
  memStart += block_size
  # inc(memStart, block_size)

  if availableMemory < block_size:
    let wasmPagesToAllocate = block_size div wasmPageSize + 1
    let oldPages = wasmMemoryGrow(int32(wasmPagesToAllocate))
    if oldPages < 0:
      return nil

    totalMemory += wasmPagesToAllocate * wasmPageSize

proc mmap(a: pointer, len: csize_t, prot, flags, fildes: cint, off: int): pointer {.exportc.} =
  if a != nil:
    discard
  wasmAlloc(len)

proc munmap(a: pointer, len: csize_t): cint {.exportc.} = discard

proc fwrite(p: pointer, sz, nmemb: csize_t, stream: pointer): csize_t {.exportc.} = discard

proc exit(code: cint) {.exportc.} = discard

proc fflush(stream: pointer): cint {.exportc.} = discard

when not defined(gcDestructors):
  GC_disable()

import std/compilesettings

# Compiler and linker options
static:
  # Nim will pass -lm and -lrt to linker, so we provide stubs, by compiling empty c file into nimcache/lib*.a, and pointing
  # the linker to nimcache
  const nimcache = querySetting(nimcacheDir)
  {.passL: "-L" & nimcache.}
  var compilerPath = querySetting(ccompilerPath)
  echo compilerPath
  if compilerPath == "":
    compilerPath = "/usr/bin/clang-15"
  when defined(windows):
    discard staticExec("mkdir " & nimcache)
  else:
    discard staticExec("mkdir -p " & nimcache)
  discard staticExec(compilerPath & " -c --target=wasm32-unknown-unknown-wasm -o " & nimcache & "/libm.a -x c -", input = "\n")
  discard staticExec(compilerPath & " -c --target=wasm32-unknown-unknown-wasm -o " & nimcache & "/librt.a -x c -", input = "\n")
