import std/[algorithm, times, strformat, stats, random]
include cowstrings

const
  DataLen = 100
  MaxIter = 10_000

type
  Customer1* = object
    registered*, verified*: Time
    username*: String
    name*, surname*: String

  Customer2* = object
    registered*, verified*: Time
    username*: string
    name*, surname*: string

proc warmup() =
  # Warmup - make sure cpu is on max perf
  let start = cpuTime()
  var a = 123
  for i in 0 ..< 300_000_000:
    a += i * i mod 456
    a = a mod 789
  let dur = cpuTime() - start
  echo &"Warmup: {dur:>4.4f} s ", a

proc printStats(name: string, stats: RunningStat, dur: float) =
  echo &"""{name}:
  Collected {stats.n} samples in {dur:.4} seconds
  Average time: {stats.mean * 1000:.4} ms
  Stddev  time: {stats.standardDeviationS * 1000:.4} ms
  Min     time: {stats.min * 1000:.4} ms
  Max     time: {stats.max * 1000:.4} ms"""

template bench(name, samples, code: untyped) =
  var stats: RunningStat
  let globalStart = cpuTime()
  for i in 0 ..< samples:
    let start = cpuTime()
    code
    let duration = cpuTime() - start
    stats.push duration
  let globalDuration = cpuTime() - globalStart
  printStats(name, stats, globalDuration)

proc fakeName(maxLen: Natural): string =
  result = newString(rand(maxLen))
  for i in 0 ..< result.len:
    result[i] = rand('A'..'Z')

template modify(x, prc: untyped) =
  for i in countdown(x.high, 1):
    if rand(1.0) > 0.98:
      x[i] = prc

proc test1 =
  var data = newSeq[Customer1](DataLen)
  for i in 0 ..< DataLen:
    data[i] = Customer1(registered: getTime(), username: toStr(fakeName(125)))
  var lastTime = data[^1].registered
  bench("Sort object with String", MaxIter):
    modify(data, Customer1(registered: getTime(), username: toStr(fakeName(125))))
    sort(data, proc (x, y: Customer1): int = cmp(x.username, y.username))
    lastTime = data[^1].registered
  echo lastTime

proc test2 =
  var data = newSeq[Customer2](DataLen)
  for i in 0 ..< DataLen:
    data[i] = Customer2(registered: getTime(), username: fakeName(125))
  var lastTime = data[^1].registered
  bench("Sort object with strings", MaxIter):
    modify(data, Customer2(registered: getTime(), username: fakeName(125)))
    sort(data, proc (x, y: Customer2): int = cmp(x.username, y.username))
    lastTime = data[^1].registered
  echo lastTime

warmup()
test1()
test2()

# Warmup: 1.5157 s 224
# Sort object with prefix String:
#   Collected 10000 samples in 0.1206 seconds
#   Average time: 0.01171 ms
#   Stddev  time: 0.006656 ms
#   Min     time: 0.002180 ms
#   Max     time: 0.04381 ms
# 2024-07-18T11:46:20+03:00
# Sort object with std strings:
#   Collected 10000 samples in 0.1266 seconds
#   Average time: 0.01230 ms
#   Stddev  time: 0.006996 ms
#   Min     time: 0.002151 ms
#   Max     time: 0.05527 ms
# 2024-07-18T11:46:20+03:00
