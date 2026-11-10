# Single-operation probe controls

Run from the checkout root in the pinned environment.

```sh
./tools/container python3 tests/phase7/campaign/test_operation_probe.py
```

The test builds two audited static runtime archives and one binary32 probe
per selected operation. The direct references are the selected typed math
symbol and the packet I/O and errno functions. The wire layout and numeric
operation IDs match the independent MPFR packet oracle. A probe rejects a
packet addressed to a different operation.

The controls cover `exp2f` and `powf` with the fixed binary32 second
operand `0x40400000` (3.0). They compare all four rounding modes against
MPFR and the original all-operation executable. In the isolated build
directory, a changed `lgammaf` archive member changes the all-operation
executable and leaves both specialized ELFs byte-identical. A changed
selected member changes the specialized ELF. The comparison also rejects
a changed oracle identity.

The report at `build/operation-probe-controls/report.json` records the
clean source snapshot, archive and executable identities, independent
packet observations, and comparison results. Build artifacts and linker
maps remain in the run directory named in the report. Equality records
report zero new observations and zero release credit. Existing campaign
ledgers and the tier continue to use their original evidence format.
