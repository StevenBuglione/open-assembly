# Resumable binary32 transcendental campaigns

A campaign is tied to a passing source-bound Phase 7 transcendental gate,
the exact startup object, library, binary32 probe object and probe ELF,
the oracle backend and its inputs, one operation, one rounding mode and
an explicit half-open input interval. Binary operations also require the
fixed second operand's raw bits. A full first-operand axis of a binary
function leaves the two-operand domain incomplete.

Run from the checkout root in the pinned environment. The artifact
collector rebuilds the files if the original verified copies are unavailable.

```sh
./tools/container make phase7-transcendental
./tools/container python3 tests/phase7/campaign/collect_artifacts.py \
    build/evidence/phase7-transcendental.json build/campaign-input
tests/phase7/campaign/native_headers.sh build/campaign-input/headers
./tools/container python3 tests/phase7/campaign/test_campaign.py \
    build/evidence/phase7-transcendental.json build/campaign-input \
    --native-headers build/campaign-input/headers
```

Prepare the native `exp2f` nearest-even campaign. Omitting `--native-headers`
selects the Python oracle. The native helper uses the pinned MPFR
shared library, with headers copied from the same Nix pin. Setup builds
the helper twice and binds the helper ELF, headers, shared library and
oracle sources to the new campaign identity. The candidate ELF comes
unchanged from the passing transcendental gate.

```sh
./tools/container python3 tests/phase7/campaign/campaign.py prepare \
    build/phase7-campaign/exp2f-native build/evidence/phase7-transcendental.json \
    build/campaign-input exp2 --mode 0 --width 262144 \
    --native-headers build/campaign-input/headers
./tools/container python3 tests/phase7/campaign/campaign.py run \
    build/phase7-campaign/exp2f-native --workers 4
```

Use `--limit N` to finish at most N new shards. Interrupting the run leaves
completed checkpoints available for the next invocation. Each checkpoint
is fsynced and atomically published only after the exact interval and
candidate results pass. The run lock excludes another writer. An audit
can independently read the published coverage while the runner works.

```sh
./tools/container python3 tests/phase7/campaign/audit.py \
    build/phase7-campaign/exp2f-native
```

The journal checks complete, disjoint coverage before marking the full
binary32 unary domain complete. The native unary helper covers all 23 unary
binary32 transcendental entries. The optional native binary helper covers
`powf` and `atan2f` with one explicit fixed second-operand encoding. Both
operations also support the Python backend. Each operation and rounding
mode uses its own campaign identity and checkpoint directory.
The benchmark in `measure_native.py` compares its request and expected
response bytes with the independent Python path at directed boundaries
in all four modes. Select an operation with `--operation`. Exact powers, signed zeros,
logarithm poles, trigonometric infinities, NaN quieting and range errors
are checked separately from the one-ULP normal-value allowance. Any nonzero checker result preserves its first
diagnostic and prevents silently resuming past a known semantic mismatch.
Candidate outputs, errno, exceptions and control-state bits are all
checked. Campaign counts stay separate across candidate artifacts,
rounding modes and oracle backends.

Prepare a native nearest-even sweep of the first operand of `powf(x, 3)`.
Use `atan2 --second 0x3f800000` for `atan2f(x, 1)` and a separate ledger.

```sh
./tools/container python3 tests/phase7/campaign/campaign.py prepare \
    build/phase7-campaign/powf-exponent-three build/evidence/phase7-transcendental.json \
    build/campaign-input pow --second 0x40400000 --mode 0 --width 262144 \
    --native-headers build/campaign-input/headers
./tools/container python3 tests/phase7/campaign/campaign.py run \
    build/phase7-campaign/powf-exponent-three --workers 2
```

The binary backend checks the operation, mode, second operand, first-operand
interval and exception seeds in every produced packet before execution.
The ledger records the native helper and resolved library identities, exact
request and response digests, and the archive and candidate ELF from the
passing gate. The [native binary oracle proof](native-binary.md) compares
its packets and acceptance policy against the Python oracle.

[MPFR reference manual](https://www.mpfr.org/mpfr-current/mpfr.html)

The tier recognizes 92 separate unary domains from 23 operations and
four rounding modes. Each needs all 2^32 input encodings on one current
candidate and oracle identity. A complete fixed-second-operand sweep of
`powf` or `atan2f` counts as one axis only. The Cartesian domain for
either binary operation in one mode contains 2^64 pairs and remains
unattempted as a complete domain.

The source gate binds the complete project input snapshot used by the
Phase 7 checks. A change anywhere in that snapshot makes earlier ledgers
historical for the current tier. Archived reports retain their original
archive, probe and oracle identities. The tier grants no current coverage
on the basis of a historical report.

The one-worker cost varies substantially by operation and input range.
The sampled gamma run took about 180 seconds for a 262,144-input shard.
Choose a smaller shard width for a new expensive campaign if needed to
stay inside the runner's subprocess budget. A different width produces
a distinct campaign identity and must keep its own checkpoint set.
