Independent large public copies, base 86524231a07695bf1f42d5e969bdc061d0ab43e1

The test author reads only the public TOMLs, the project ABI and previous
independent fixtures. No runtime implementation or disassembly was inspected.
These are new inputs; existing Phase2 and wide-memory assertions stay unchanged.
The suite measures public memcpy, wmemcpy and memmove and does not establish a
private helper's branch coverage or full production qualification.

C17 7.24.2.1 specifies exact disjoint byte copying and its destination return;
7.24.2.2 specifies a temporary-copy result for memmove overlap. C17 7.29.4.2.3
specifies exact disjoint wide-element copying. Project wmemcpy additionally
preserves errno. The byte-copy TOMLs make no explicit errno-preservation promise,
so their errno is not part of the comparison. glibc and musl are executed as
additional oracles; the scalar reference remains independent of both.

Every first typed call is positive: 1025 bytes for memcpy/memmove, 257 actual
wchar_t elements for wmemcpy. The shared SysV trampoline captures RAX and checks
RSP, DF, six callee-saved GPRs, MXCSR controls, x87 controls and stack emptiness.
Native and QEMU run it. Valgrind's independently observed no-op callback control
mask 0x300 prevents an ABI-control claim there; ordinary/guard/packet cases still
run under strict Memcheck. Every test object must strongly reference the actual
public symbol and the linked ELF must define it. Stubs use the automatic
public typed-zero generator, selected by name, with the ordinary case first.

There are 35 length selectors. They include zero, first positive bulk requests,
powers-of-two neighbors around 16/32/64/256/512/1024/2048, page neighbors and
multiple pages. With the observed 4096-byte pages the largest requests are
16385 bytes or 4097 wchar_t elements (16388 bytes). C arrays and mapped storage
are owned and initialized; wchar_t pointers have proper alignment. Source and
destination are disjoint for memcpy/wmemcpy. Seven memmove layouts cover separate
objects, destination-after/source-after overlap by 1 and 17 bytes, identical
pointers, and disjoint ranges in one object. Expected overlap results use an
independent pre-call snapshot. All pointer arithmetic stays in owned spans.

Ordinary tests fill the entire readable object, including prefix/suffix padding,
and compare all bytes after the call. The scalar model operates through volatile
accesses and imports no copy primitive; standalone model object undefined-symbol
sets must be empty with candidate headers, glibc and musl. Packet object audits
allow only the three direct tested symbols, errno, the raw kernel boundary and
auxv (or hosted syscall/sysconf). New page guards use real owned PROT_NONE
boundaries on each side of twelve readable pages. Guard selectors place exact
source/destination ranges against either boundary; memmove bounds the legal
union. Count-zero pointer arguments remain aligned within the owned mappings,
including their readable-span endpoint. No invented address, private state or
candidate metadata is used. Guard SIGSEGV/SIGBUS remain raw unclassified faults;
there is no generic signal-to-semantic-rejection conversion.

The fixed packet is independently computed by golden.py for a one-unit copy at
seed197 on 4096-byte pages. Its literal expected bytes live in manifest.toml.
Stimulus: two little-endian uint64_t words, selector and seed (16 bytes).
Result: eight little-endian uint64_t words (64 bytes): normalized return success,
byte count, element count, source offset, destination offset, memmove layout,
source digest and destination digest. Digests cover the entire initialized
12-page object after the independently verified copy. They omit dynamic
addresses; comparisons otherwise use exact bytes, with no host normalization.
Selector low8 chooses length modulo35; bits8..10 choose move layout modulo7;
top2 bits choose guard edges in the separate guard mode. Timed packets use the
ordinary readable-padding placement and raw seed-derived byte/word offsets.

Each function receives its own reproducible >=60-second candidate/glibc/musl
comparison, seed1551710881, 512 rows per batch. Reports retain input/output hashes,
actual elapsed time and row counts plus selected-length/layout histograms. Sampled
packets are not exhaustive. Sources and both independently rebuilt runtime
artifact dictionaries are hash-bound, with a final unchanged-input check.

Exact silent status protocol:
11 typed machine state; 12 typed return pointer; 13 typed copied bytes or
source/canaries; 21 ordinary return pointer; 22 destination copied bytes;
23 source or bytes outside the destination; 24 specified wmemcpy errno;
90 bad invocation; 91 mapping/protection setup; 92 unmap; 93 unsupported page;
94 truncated/failed input; 95 packet output. Zero stubs must return21 in each
ordinary case. Mapping/setup/transport errors and arbitrary process faults are
not semantic mutation kills.

The first runner snapshot passed all fixed cases and stubs, then failed its
standalone-model audit because an export dictionary was passed as an include
path. That is harness failure, not a candidate discrepancy. The original
rj4BTM snapshot/report is preserved; the successor corrects only that runner
argument and adds this documentation and reproducible golden generator.
