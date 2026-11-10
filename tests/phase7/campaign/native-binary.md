# Native binary32 fixed-operand MPFR packets

Build and compare the native producer with the original Python oracle in the
pinned environment.

```sh
tests/phase7/campaign/native_headers.sh build/native-binary-headers
./tools/container python3 tests/phase7/campaign/test_native_binary.py \
    build/native-binary-headers build/native-binary-parity.json
```

The proof builds two identical copies of the test-only producer and records
its loaded MPFR, GMP and interpreter identities. It compares the original
32-byte request and 16-byte expected response for `powf` and `atan2f`
in all four rounding modes. Directed windows include signed zeros,
subnormals, range boundaries, infinities, quiet and signaling NaNs,
exact powers, and exponents near the integer parity boundary. The comparison
also checks the request exception seed, expected flags, and errno. The
producer takes an operation, first encoding, count, mode, fixed second
encoding, and separate request and response paths.

The binary comparator derives the permitted quiet NaN cases from the two
request encodings and the expected domain result. Seeded response controls
compare its acceptance to the Python checker, including exact payloads,
allowed quiet payload variation, signed zero, range results, one-ULP
normal results, errno, exception flags, and control-state changes.

Each fixed second operand describes one first-operand axis. The proof
samples these axes, with zero release credit. Full coverage of one axis
would still cover only 2^32 of the 2^64 input pairs in one rounding mode.
