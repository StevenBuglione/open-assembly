# Phase 11 allocator benchmark plan

Measure the default static Open Assembly and pinned static musl allocators
with the same freestanding C17 test source. Disable compiler builtins and
verify the unresolved allocation references and final archive origin before
running. Use a quiet native Linux runner with a single pinned allowed CPU.
Use the one-second 90% idle preflight and per-sample wall-time versus thread
CPU-time check specified in [ADR 0035](../adr/0035-memcpy-dispatch.md).

Run one untimed warmup followed by nine alternating pairs for each timing
workload. Check the payload and final checksum before retaining any timing.
The median Open Assembly time must be at most 1.50 times the musl median in
each workload. The geometric mean of those three ratios must be at most 1.25.

- Small allocations use 512 slots and 2,048 batches of 32-byte blocks. Each
  batch fills every slot, touches both ends of every block, verifies the
  markers, and frees in a fixed odd-stride permutation.
- Mixed allocations use 512 slots and 256 batches. The requested size cycles
  through `1, 15, 24, 40, 72, 120, 248, 504, 1000, 2032, 4096, 7000, 16384,
  65536`. Each batch fills every slot, touches each page and the last byte,
  verifies the markers, and frees in the same fixed permutation.
- Direct growth uses 16 independent `realloc` chains from 64 KiB through
  each power of two up to 8 MiB. Touch every newly added page and the last
  byte, verify earlier page markers at each step, and free each result.
  Both in-place and moved success are valid. The syscall-path oracle is a
  separate check of the optimization.

Record nine additional alternating pairs for RSS. Each process takes Linux
`/proc/self/smaps_rollup` `Rss` samples before allocating, after touching
8,192 blocks with the mixed sizes above, after releasing all except every
17th block, and after releasing the remainder. Keep the peak sample for
context and compare retained and released RSS deltas from each process's
own baseline. Each median Open Assembly delta must be at most the
corresponding musl delta plus 8 MiB. Report raw samples and any negative
deltas caused by process accounting changes. A missing RSS source or a
missing quiet CPU leaves the applicable measurement incomplete.

The current allocator optimization covers direct growth. These workloads
will measure that path and the existing small-block and mixed-class behavior.
Additional throughput or space changes need separately reviewed evidence.
