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
binary32 unary domain complete. The native helper covers `exp2f` and `log2f`. Each operation and rounding
mode uses its own campaign identity and checkpoint directory.
The benchmark in `measure_native.py` compares its request and expected
response bytes with the independent Python path at directed boundaries
in all four modes. Select `--operation log2` to measure the logarithm
against the same candidate ELF. Its exact powers and signed pole cases
are checked separately from the one-ULP normal-value allowance. Any nonzero checker result preserves its first
diagnostic and prevents silently resuming past a known semantic mismatch.
Candidate outputs, errno, exceptions and control-state bits are all
checked. Campaign counts stay separate across candidate artifacts,
rounding modes and oracle backends.

[MPFR reference manual](https://www.mpfr.org/mpfr-current/mpfr.html)
