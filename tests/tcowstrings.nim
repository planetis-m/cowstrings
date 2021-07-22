import cowstrings
import std/isolation

proc main =
  block:
    var a = initStringOfCap(10)
    a.add 'h'
    var b = a
    b.add a
    b.add 'w'
    echo a.toCStr # prevent sink
    echo b.toCStr
  block:
    var a: String
    a.add 'h'
    a.add 'e'
    echo a.toCStr
  block:
    var a: Isolated[String]
    var b: String
    b.add 'w'
    b.add 'o'
    a = isolate b
    #b.add 'r'
    let c = extract a
    echo c.toCStr

main()
