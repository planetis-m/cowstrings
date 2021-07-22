import sync/spsc, cowstrings

const
  seed = 99
  bufCap = 20
  numIters = 1000

template sendLoop(tx, data: typed, body: untyped): untyped =
  while not tx.trySend(data):
    body

template recvLoop(rx, data: typed, body: untyped): untyped =
  while not rx.tryRecv(data):
    body

proc consume(rx: SpscReceiver[String]) =
  for i in 0 ..< numIters:
    var res: String
    recvLoop(rx, res): cpuRelax()
    #echo " >> received ", res.toCstr, " ", $(seed + i)
    assert res == toStr($(seed + i))

proc produce(tx: SpscSender[String]) =
  for i in 0 ..< numIters:
    var p = isolate(toStr($(i + seed)))
    sendLoop(tx, p): cpuRelax()
    #echo " >> sent ", $(i + seed)

proc testSpScRing =
  let (tx, rx) = newSpscChannel[String](bufCap) # tx for transmission, rx for receiving
  var
    thr1: Thread[SpscSender[String]]
    thr2: Thread[SpscReceiver[String]]
  createThread(thr1, produce, tx)
  createThread(thr2, consume, rx)
  joinThread(thr1)
  joinThread(thr2)

testSpScRing()
