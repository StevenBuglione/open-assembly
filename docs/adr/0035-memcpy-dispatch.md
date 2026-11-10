# CPU dispatch for large memcpy

Status: proposed, scoped to this Phase 11 memory routine.

`memcpy` keeps its byte-exact baseline for fewer than 256 bytes.
Larger copies enter a private implementation that supports an SSE2
path on every project CPU. AVX vector moves are enabled only when
CPUID leaf 1 reports XSAVE, OSXSAVE and AVX, and XGETBV reports both
XMM and YMM state enabled in XCR0. The feature result is cached in an
aligned process-local word. Reentrant or concurrent initialization
may repeat discovery. This assumes the Linux process sees a uniform
usable ISA across its allowed CPUs, as with the pinned hardware and
emulation controls. [AMD64 psABI](https://gitlab.com/x86-psABIs/x86-64-ABI/-/raw/master/x86-64-ABI/low-level-sys-info.tex) · [Intel architecture manuals](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html)

Both paths return the original destination and copy exactly the
requested bytes, including unaligned and guarded ranges. The AVX path
executes VZEROUPPER before returning to baseline instructions. The
static checker accepts the optional ISA only in the exact feature
decision and bounded copy sequence. Verification must distinguish
baseline execution, missing OS vector state, and accelerated
execution. The existing public memcpy ABI, oracle, guard, branch
coverage and mutation requirements continue to apply.

The benchmark is scoped to warm, disjoint copies of 256, 1,024, 4,096,
65,536 and 1,048,576 bytes, using cyclic source and destination offsets
from 0 through 31 and 128 MiB per sample. Measure nine alternating
pairs of Open Assembly and pinned musl executions on the same
allowed native CPU. Link the assembly candidate through its ordinary
static startup and disable compiler builtins in both harnesses.
Exclude one untimed warmup and verify a copied-byte checksum.
The acceptance margin is at most 1.25 times the geometric mean of
per-size median times and at most 1.50 times musl's median at every
size. The margin and workload are fixed before measurements.
