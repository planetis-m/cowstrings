import cowstrings, sync/spsc_queue

const
  numIters = 200

var
  pong: Thread[void]
  q1: SpscQueue[String]
  q2: SpscQueue[String]

template pushLoop(tx, data: typed, body: untyped): untyped =
  while not tx.tryPush(data):
    body

template popLoop(rx, data: typed, body: untyped): untyped =
  while not rx.tryPop(data):
    body

proc pongFn {.thread.} =
  while true:
    var n: String
    popLoop(q1, n): discard
    var p = isolate(n)
    pushLoop(q2, p): discard
    #sleep 20
    if n[0] == '0': break
    assert n == toStr("1")

proc pingPong =
  q1 = newSpscQueue[String](2000)
  q2 = newSpscQueue[String](2000)
  createThread(pong, pongFn)
  for i in 1..numIters:
    var p = isolate(toStr("1"))
    pushLoop(q1, p): discard
    var n: String
    #sleep 10
    popLoop(q2, n): discard
    assert n == toStr("1")
  var p = isolate(toStr("0"))
  pushLoop(q1, p): discard
  var n: String
  popLoop(q2, n): discard
  assert n == toStr("0")
  pong.joinThread()

pingPong()
