import cowstrings
import std/isolation

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
    var a: String
    a.add 'h'
    a.add 'e'
    assert a == cstring"he".toStr
  block:
    var a: Isolated[String]
    var b: String
    b.add 'w'
    b.add 'o'
    a = isolate b
    #b.add 'r'
    let c = extract a
    assert c == cstring"wo".toStr
  block:
    let a = cstring"World".toStr
    var b = a
    prepareStrMutation(b)
    b[0] = 'P'
    assert a == cstring"World".toStr

main()
