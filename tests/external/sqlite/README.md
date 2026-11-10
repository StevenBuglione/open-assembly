# Pinned upstream SQLite workloads

The offline gate uses SQLite 3.53.3 from its official source and
amalgamation archives. The release source ID is
`d4c0e51e4aeb96955b99185ab9cde75c339e2c29c3f3f12428d364a10d782c62`.
The gate verifies both archives and the exact extracted C sources.
The upstream sources are public domain. Their bytes enter the pinned
Nix image before the network-disabled gate starts.

The single-threaded `speedtest1` build runs with `--verify --size 1
--journal wal --mmap 1048576 --checkpoint --testset
main,cte,json,parsenumber`. The result hash includes 111,316 bytes
and must be `5353830536d24573b658f66a0e0c93c215f76f53f4d856e2`.
The gate checks the first main test and the three later set markers.
Elapsed times are ignored.

The thread-enabled `threadtest3 shared1` workload launches five
concurrent readers against a file-backed shared-cache database. It
requires five distinct worker completion lines and the upstream
zero-error result. The upstream harness assumes a transitive definition
of `intptr_t`, so the compiler pre-includes `stdint.h` for that one
source file. The separate `threadtest5 --num-workers 1` run uses the
upstream memory database and verifies all 100 distinct tasks and the
final `OK`.

The builds disable dynamic load extensions and use the release-style
NDEBUG and Linux nanosleep configuration. Each candidate links only
the project startup, project archive, and upstream application
objects. The gate runs native Linux, QEMU, and Memcheck alongside
pinned glibc and musl controls.

## Concurrent write observations

The four-worker memory variant of `threadtest5` can complete every task
and still fail the upstream final `p2 EXCEPT p1` assertion. This occurred
on Open Assembly, glibc, and musl under QEMU. Task 52 creates the table
and populates it in separate SQL statements. Tasks 53–62 wait for table
existence, then delete composites. A deterministic two-connection
control on both hosted libcs left composite 4 after CREATE, DELETE,
INSERT and removed it after CREATE, INSERT, DELETE.

The file-backed four-worker variant returned `database is locked` at
upstream line 166 on native Open Assembly and glibc. A separate
`threadtest4 --serialized 2` run completed 62 checks on native and QEMU
with Open Assembly and on hosted musl. It encountered a schema lock
under Memcheck and an upstream VACUUM deadlock with hosted glibc.
These are separate observations. The full Tcl suite and concurrent
write acceptance have distinct scopes.

[SQLite 3.53.3 release](https://www.sqlite.org/releaselog/3_53_3.html) ·
[SQLite public domain statement](https://www.sqlite.org/copyright.html)
