
{.push stackTrace: off.}

# If we're using HeapAlloc, do the appropriate FFI items to import it.  Because we're in the system library, even importing
# Nim's windows/winlean doesn't work well (no dynlib), so we have to do imports the old fashioned way.
when defined(winMallocMeansHeapAlloc):
  #import dynlib
  #import lib/windows/winlean

  type
    DWORD = int32
    Handle = int
    WINBOOL = int32
    
  const
    HEAP_ZERO_MEMORY = 0x00000008

  proc HeapAlloc(hHeap: Handle, dwFlags: DWORD, dwBytes: csize_t): pointer {.stdcall, header: "<Windows.h>", importc, sideEffect.}
  proc GetProcessHeap(): Handle {.stdcall, header: "<Windows.h>", importc, sideEffect.}
  proc HeapReAlloc(hHeap: Handle, dwFlags: DWORD, lpMem: pointer, dwBytes: csize_t): pointer {.stdcall, header: "<Windows.h>", importc, sideEffect.}
  proc HeapFree(hHeap: Handle, dwFlags: DWORD, lpMem: pointer): WINBOOL {.stdcall, header: "<Windows.h>", importc, sideEffect.}

proc allocImpl(size: Natural): pointer =
  when defined(winMallocMeansHeapAlloc):
    HeapAlloc(GetProcessHeap(), 0, size.csize_t)
  else:
    c_malloc(size.csize_t)

proc alloc0Impl(size: Natural): pointer =
  when defined(winMallocMeansHeapAlloc):
    HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, size.csize_t)
  else:
    c_calloc(size.csize_t, 1)

proc reallocImpl(p: pointer, newSize: Natural): pointer =
  when defined(winMallocMeansHeapAlloc):
    HeapReAlloc(GetProcessHeap(), 0, p, newSize.csize_t)
  else:
    c_realloc(p, newSize.csize_t)

proc realloc0Impl(p: pointer, oldsize, newSize: Natural): pointer =
  when defined(winMallocMeansHeapAlloc):
    HeapReAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, p, newSize.csize_t)
  else:
    result = realloc(p, newSize.csize_t)
    if newSize > oldSize:
      zeroMem(cast[pointer](cast[int](result) + oldSize), newSize - oldSize)

proc deallocImpl(p: pointer) =
  when defined(winMallocMeansHeapAlloc):
    discard HeapFree(GetProcessHeap(), 0, p)
  else:
    c_free(p)


# The shared allocators map on the regular ones

proc allocSharedImpl(size: Natural): pointer =
  allocImpl(size)

proc allocShared0Impl(size: Natural): pointer =
  alloc0Impl(size)

proc reallocSharedImpl(p: pointer, newSize: Natural): pointer =
  reallocImpl(p, newSize)

proc reallocShared0Impl(p: pointer, oldsize, newSize: Natural): pointer =
  realloc0Impl(p, oldSize, newSize)

proc deallocSharedImpl(p: pointer) = deallocImpl(p)


# Empty stubs for the GC

proc GC_disable() = discard
proc GC_enable() = discard

when not defined(gcOrc):
  proc GC_fullCollect() = discard
  proc GC_enableMarkAndSweep() = discard
  proc GC_disableMarkAndSweep() = discard

proc GC_setStrategy(strategy: GC_Strategy) = discard

proc getOccupiedMem(): int = discard
proc getFreeMem(): int = discard
proc getTotalMem(): int = discard

proc nimGC_setStackBottom(theStackBottom: pointer) = discard

proc initGC() = discard

proc newObjNoInit(typ: PNimType, size: int): pointer =
  result = alloc(size)

proc growObj(old: pointer, newsize: int): pointer =
  result = realloc(old, newsize)

proc nimGCref(p: pointer) {.compilerproc, inline.} = discard
proc nimGCunref(p: pointer) {.compilerproc, inline.} = discard

when not defined(gcDestructors):
  proc unsureAsgnRef(dest: PPointer, src: pointer) {.compilerproc, inline.} =
    dest[] = src

proc asgnRef(dest: PPointer, src: pointer) {.compilerproc, inline.} =
  dest[] = src
proc asgnRefNoCycle(dest: PPointer, src: pointer) {.compilerproc, inline,
  deprecated: "old compiler compat".} = asgnRef(dest, src)

type
  MemRegion = object

proc alloc(r: var MemRegion, size: int): pointer =
  result = alloc(size)
proc alloc0Impl(r: var MemRegion, size: int): pointer =
  result = alloc0Impl(size)
proc dealloc(r: var MemRegion, p: pointer) = dealloc(p)
proc deallocOsPages(r: var MemRegion) = discard
proc deallocOsPages() = discard

{.pop.}
