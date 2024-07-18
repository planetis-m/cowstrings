import std/[isolation, hashes]

when defined(nimPreviewSlimSystem):
  import std/assertions

type
  StrPayloadBase = object
    cap, counter: int32

  StrPayload = object
    cap, counter: int32
    data: UncheckedArray[char]

  String* = object
    len: int32
    prefix: array[4, char]
    p: ptr StrPayload # can be nil if len == 0.

template contentSize(cap): int = cap + 1 + sizeof(StrPayloadBase)

template frees(s) =
  when compileOption("threads"):
    deallocShared(s.p)
  else:
    dealloc(s.p)

proc `=destroy`*(x: String) =
  if x.p != nil:
    if x.p.counter == 0:
      frees(x)
    else:
      dec x.p.counter

proc `=wasMoved`*(x: var String) =
  x.p = nil

template dups(a, b) =
  if b.p != nil:
    inc b.p.counter
  a.p = b.p
  a.len = b.len
  a.prefix = b.prefix

proc `=dup`*(b: String): String =
  dups(result, b)

proc `=copy`*(a: var String, b: String) =
  `=destroy`(a)
  dups(a, b)

proc deepCopy*(y: String): String =
  if y.len <= 0:
    result = String(len: 0, p: nil)
  else:
    when compileOption("threads"):
      let p = cast[ptr StrPayload](allocShared(contentSize(y.len)))
    else:
      let p = cast[ptr StrPayload](alloc(contentSize(y.len)))
    p.cap = y.len
    p.counter = 0
    # also copy the \0 terminator:
    copyMem(addr p.data[0], addr y.p.data[0], y.len+1)
    result = String(len: y.len, p: p, prefix: y.prefix)

proc resize(old: int32): int32 {.inline.} =
  if old <= 0: result = 4
  elif old <= high(int16): result = old * 2
  else: result = old * 3 div 2 # for large arrays * 3/2 is better

proc prepareAdd(s: var String; addLen: int32) =
  let newLen = s.len + addLen
  # copy the data iff there is more than a reference or its a literal
  if s.p == nil or s.p.counter > 0:
    let oldP = s.p # can be nil
    # can't mutate a literal, so we need a fresh copy here:
    when compileOption("threads"):
      s.p = cast[ptr StrPayload](allocShared0(contentSize(newLen)))
    else:
      s.p = cast[ptr StrPayload](alloc0(contentSize(newLen)))
    s.p.cap = newLen
    s.p.counter = 0
    if s.len > 0:
      dec oldP.counter
      # we are about to append, so there is no need to copy the \0 terminator:
      copyMem(addr s.p.data[0], addr oldP.data[0], min(s.len, newLen))
  else:
    let oldCap = s.p.cap
    if newLen > oldCap:
      let newCap = max(newLen, resize(oldCap))
      when compileOption("threads"):
        s.p = cast[ptr StrPayload](reallocShared0(s.p, contentSize(oldCap), contentSize(newCap)))
      else:
        s.p = cast[ptr StrPayload](realloc0(s.p, contentSize(oldCap), contentSize(newCap)))
      s.p.cap = newCap

proc add*(s: var String; c: char) {.inline.} =
  prepareAdd(s, 1)
  s.p.data[s.len] = c
  s.p.data[s.len+1] = '\0'
  if s.len < 4:
    s.prefix[s.len] = c
  inc s.len

proc add*(dest: var String; src: String) {.inline.} =
  if src.len > 0:
    prepareAdd(dest, src.len)
    # also copy the \0 terminator:
    copyMem(addr dest.p.data[dest.len], addr src.p.data[0], src.len+1)
    if dest.len < 4:
      copyMem(addr dest.prefix[dest.len], addr src.p.data[0], min(4 - dest.len, src.len))
    inc dest.len, src.len

proc cstrToStr(str: cstring, len: int32): String =
  if len <= 0:
    result = String(len: 0, p: nil)
  else:
    when compileOption("threads"):
      let p = cast[ptr StrPayload](allocShared(contentSize(len)))
    else:
      let p = cast[ptr StrPayload](alloc(contentSize(len)))
    p.cap = len
    p.counter = 0
    copyMem(addr p.data[0], str, len+1)
    result = String(len: len, p: p)
    copyMem(addr result.prefix, addr result.p.data[0], min(4, len))

proc toStr*(str: cstring): String {.inline.} =
  if str == nil: cstrToStr(str, 0)
  else: cstrToStr(str, str.len.int32)

proc toStr*(str: string): String {.inline.} =
  cstrToStr(str.cstring, str.len.int32)

proc toCStr*(s: String): cstring {.inline.} =
  if s.len == 0: result = cstring""
  else: result = cast[cstring](addr s.p.data)

proc toNimStr*(s: String): string =
  result = newStringUninit(s.len)
  copyMem(cstring(result), toCStr(s), result.len)

proc initStringOfCap*(space: Natural): String =
  # this is also 'system.newStringOfCap'.
  if space <= 0:
    result = String(len: 0, p: nil)
  else:
    when compileOption("threads"):
      let p = cast[ptr StrPayload](allocShared0(contentSize(space)))
    else:
      let p = cast[ptr StrPayload](alloc0(contentSize(space)))
    p.cap = space.int32
    p.counter = 0
    result = String(len: 0, p: p)

proc initString*(len: Natural): String =
  if len <= 0:
    result = String(len: 0, p: nil)
  else:
    when compileOption("threads"):
      let p = cast[ptr StrPayload](allocShared0(contentSize(len)))
    else:
      let p = cast[ptr StrPayload](alloc0(contentSize(len)))
    p.cap = len.int32
    p.counter = 0
    result = String(len: len.int32, p: p)

proc setLen*(s: var String, newLen: Natural) =
  if newLen == 0:
    discard "do not free the buffer here, pattern 's.setLen 0' is common for avoiding allocations"
    reset(s.prefix)
  else:
    if newLen > s.len or s.p == nil:
      prepareAdd(s, newLen.int32 - s.len)
    elif newLen < 4:
      zeroMem(addr s.prefix[newLen], 4 - newLen)
    s.p.data[newLen] = '\0'
  s.len = newLen.int32

proc len*(s: String): int {.inline.} = s.len
proc high*(s: String): int {.inline.} = s.len-1
proc low*(s: String): int {.inline.} = 0

proc isolate*(value: sink String): Isolated[String] =
  # Ensure uniqueness
  if value.p == nil or value.p.counter == 0:
    result = unsafeIsolate value
  else:
    result = unsafeIsolate deepCopy(value)

# Comparisons
proc `==`*(a, b: String): bool =
  result = false
  if a.len == b.len:
    if a.len == 0: result = true
    elif a.prefix == b.prefix:
      result = equalMem(addr a.p.data[0], addr b.p.data[0], a.len)

proc cmp*(a, b: String): int =
  let minLen = min(a.len, b.len)
  if minLen > 0:
    result = cmpMem(addr a.p.data[0], addr b.p.data[0], minLen)
    if result == 0:
      result = a.len - b.len
  else:
    result = a.len - b.len

proc `<=`*(a, b: String): bool {.inline.} = cmp(a, b) <= 0
proc `<`*(a, b: String): bool {.inline.} = cmp(a, b) < 0

proc prepareMutation*(s: var String) {.inline.} =
  if s.p != nil and s.p.counter > 0:
    let oldP = s.p
    # can't mutate a literal, so we need a fresh copy here:
    when compileOption("threads"):
      s.p = cast[ptr StrPayload](allocShared(contentSize(s.len)))
    else:
      s.p = cast[ptr StrPayload](alloc(contentSize(s.len)))
    s.p.cap = s.len
    s.p.counter = 0
    dec oldP.counter
    copyMem(addr s.p.data[0], addr oldP.data[0], s.len+1)

proc raiseIndexDefect(i, n: int) {.noinline, noreturn.} =
  raise newException(IndexDefect, "index " & $i & " not in 0 .. " & $n)

template checkBounds(i, n) =
  when compileOption("boundChecks"):
    {.line.}:
      if i < 0 or i >= n:
        raiseIndexDefect(i, n-1)

proc `[]`*(x: String; i: int): char {.inline.} =
  checkBounds(i, x.len)
  x.p.data[i]

proc `[]`*(x: var String; i: int): var char {.inline.} =
  checkBounds(i, x.len)
  result = x.p.data[i]
  # if i < 4:
  #   x.prefix[i] = val??

proc `[]=`*(x: var String; i: int; val: char) {.inline.} =
  checkBounds(i, x.len)
  assert x.p.counter == 0, "the string is not unique, call prepareMutation beforehand"
  x.p.data[i] = val
  if i < 4:
    x.prefix[i] = val

proc `[]`*(x: String; i: BackwardsIndex): char {.inline.} =
  checkBounds(x.len - i.int, x.len)
  result = x.p.data[x.len - i.int]

proc `[]`*(x: var String; i: BackwardsIndex): var char {.inline.} =
  checkBounds(x.len - i.int, x.len)
  result = x.p.data[x.len - i.int]

proc `[]=`*(x: var String; i: BackwardsIndex; val: char) {.inline.} =
  checkBounds(x.len - i.int, x.len)
  assert x.p.counter == 0, "the string is not unique, call prepareMutation beforehand"
  x.p.data[x.len - i.int] = val
  if x.len - i.int < 4:
    x.prefix[x.len - i.int] = val

iterator items*(a: String): char {.inline.} =
  var i = 0
  let L = a.len
  while i < L:
    yield a[i]
    inc(i)
    assert(a.len == L, "the length of the string changed while iterating over it")

iterator mitems*(a: var String): var char {.inline.} =
  var i = 0
  let L = a.len
  while i < L:
    yield a[i]
    inc(i)
    assert(a.len == L, "the length of the string changed while iterating over it")

template toOpenArray*(s: String; first, last: int): untyped =
  checkBounds(first, s.len)
  checkBounds(last, s.len)
  toOpenArray(toCStr(s), first, last)

template toOpenArray*(s: String): untyped =
  toOpenArray(toCStr(s), 0, s.high)

proc hash*(x: String): Hash =
  hash(toOpenArray(x))
