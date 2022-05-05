====================================================
               Copy-On-Write String
====================================================

Copy-On-Write string data-type provides an implementation of mutable strings so
that creating and copying them is free, performance wise. The object's internal
memory is reference counted and shared among instances. Thus it only make a
copy for a specific instance, when it's data is modified. It is based on
`nim-lang/RFCs#221 <https://github.com/nim-lang/RFCs/issues/221>`_. It should
improve performance when strings are frequently copied. Passing a string to a
thread triggers a deep copy, so it is compatible with multi-threading.
