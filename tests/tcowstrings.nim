import cowstrings
import std/[enumerate, isolation, assertions]

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
    assert a == "he".toStr
  block:
    var b: String = toStr""
    b.add 'w'
    b.add 'o'
    var a = isolate b
    #b.add 'r'
    let c = extract a
    assert c == "wo".toStr
  block:
    let a = "World".toStr
    var b = a
    prepareMutation(b)
    b[0] = 'P'
    assert a == "World".toStr
  block:
    let data = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    var str = String()
    for c in data:
      str.add c
    let expected = toStr(data)
    assert str.len == data.len
    assert str == expected
  block:
    let data = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    var a: seq[String] = @[]
    for i in 0..data.len:
      let strLen = data.len - i
      let expected = data[0..<strLen]
      var str = toStr(expected)
      a.add(str)
      assert str.toCStr == expected.cstring
      assert str.len == strLen
    for i, str in enumerate(items(a)):
      let strLen = data.len - i
      let expected = data[0..<strLen]
      assert str.toCStr == expected.cstring
      assert str.len == strLen
  block:
    let str = toStr"7B"
    assert str.toNimStr == "7B"
    assert str.toOpenArray() == "7B"
    assert str.toOpenArray(0, 1) == "7B"

main()
