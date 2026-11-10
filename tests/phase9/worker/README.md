# Independent worker-local conversion state

The pinned `make phase9-worker` gate uses the combined thread and locale
runtime. The main thread and two workers interleave five null-state
conversions with different UTF-8 encodings and errno sentinels.
Each stages a split UTF-8 sequence, a queued UTF-16 result and a
pending encoder surrogate. A worker resets its own malformed state
while the other threads keep their conversions pending.

Sixteen create and join rounds leave one pending state in each
finished worker. New workers must begin with fresh state even when
a mapping is reused. Atomic release and acquire handoffs make the
overlap explicit. This test covers the project's thread-local default
state extension on native, QEMU and Memcheck. Hosted libc uses the
separate explicit-state scalar and string fixtures.

[Multibyte contract](../../../docs/adr/0012-c-utf8-multibyte.md) ·
[Thread lifecycle contract](../../../docs/adr/0010-thread-lifecycle-locks.md)
