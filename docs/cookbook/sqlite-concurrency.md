# SQLite concurrent WAL transactions

Run the pinned SQLite 3.53.3 concurrency scope in the offline container.

```sh
./tools/container make phase6-sqlite-concurrency
```

The unchanged upstream `threadtest3 walthread1` workload runs for
20 seconds on a local file-backed WAL database. It runs ten
read/write workers and one checkpoint worker. The upstream code
checks database integrity and compares the read transaction's
digest and stored digest. Each writer then commits three rows.

The gate requires positive progress from all eleven distinct
workers and the upstream zero-error summary. A separate read-only
SQLite connection reopens the final database and checks full
integrity, WAL mode, and the exact relationship between committed
rows and reported writer iterations. The database file hash
must survive that read unchanged.

The hosted glibc and musl executables each run twice on fresh
databases before the Open Assembly executable runs on native
Linux, QEMU and Memcheck. The gate binds the pinned release
bytes, two reproducible archive-only links, all observations
and the read-only verifier identity. The output is
`build/evidence/phase6-sqlite-concurrency.json`.

The upstream workload sets `synchronous=OFF`. This scope measures
concurrent WAL transactions, reader consistency and progress.
The earlier four-worker threadtest5 and threadtest4 observations
remain in the existing SQLite gate notes.

[SQLite test programs](https://sqlite.org/testing.html) ·
[Prior SQLite workloads](../../tests/external/sqlite/README.md).
