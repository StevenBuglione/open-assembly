# Pinned zlib application acceptance

Run `./tools/container make phase6-zlib`. The gate fetches the official
zlib 1.3.2 tarball by its fixed SHA-256 and verifies the upstream license.
It builds the unmodified upstream `test/example.c` and `test/minigzip.c`
with the generated test headers, links them with Open Assembly startup
and the static runtime, and checks two independent builds for equality.
The linker maps identify both the upstream zlib symbols and the actual
runtime symbols, including `fcntl` and `fileno`.

Each backend runs the upstream example and exercises minigzip against
327,680 deterministic bytes. The streams cross the pinned Python gzip
oracle in both directions. Native, QEMU user mode and Memcheck must
agree on the compressed bytes, and Memcheck runs with fatal diagnostics.
The report is `build/evidence/phase6-zlib.json`.

[Upstream source archive](https://zlib.net/fossils/zlib-1.3.2.tar.gz)
