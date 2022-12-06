import cowstrings
import std/[isolation, assertions]

proc main =
  block:
    var a = initStringOfCap(10)
    a.add 'h'
    var b = a
    b.add a
    b.add 'w'
    assert a.toCStr == cstring"h" # prevent sink
    assert b.toCStr == cstring"hhw"
  block:
    var a: String = toStr""
    a.add 'h'
    a.add 'e'
    assert a == cstring"he".toStr
  block:
    var b: String = toStr""
    b.add 'w'
    b.add 'o'
    var a = isolate b
    #b.add 'r'
    let c = extract a
    assert c == cstring"wo".toStr
  block:
    let a = cstring"World".toStr
    var b = a
    prepareMutation(b)
    b[0] = 'P'
    assert a == cstring"World".toStr

main()
