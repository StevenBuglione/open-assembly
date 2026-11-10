# Open Assembly

Open Assembly is a hand-authored NASM libc for x86-64 Linux System V,
targeting ISO C17 and a documented POSIX subset. The baseline uses SSE2
and links statically. [Project scope](docs/adr/0001-project-scope.md) ·
[Runtime ABI](docs/adr/0002-runtime-abi.md) · [API index](docs/api-index.md)

## Build and link

Run the build in the pinned Nix and Docker toolchain container.

```sh
./tools/container make runtime apps
```

The default build writes `crt1.o` and `libopenasm.a` under
`build/runtime/`, plus the assembly programs `cat`, `wc`, and `httpd`
under `build/runtime/apps/`. To link a program that exports a System V
`main`, place the startup object first, then the application objects,
then the runtime archive. The checked-in assembly hello fixture is a
minimal link example.

```sh
./tools/container sh -ec '
  nasm -f elf64 -Wno-reloc-rel-dword -o build/hello.o tests/apps/phase1/hello.asm
  ld -m elf_x86_64 -static -no-pie -z noexecstack -e _start \
    -o build/hello build/runtime/crt1.o build/hello.o build/runtime/libopenasm.a
  tools/elf-audit build/hello
  ./build/hello
'
```

The opt-in `runtime-pie` target supplies `crt1-pie.o` for the
documented GNU ld relocation subset. [Static PIE link flags](docs/adr/0028-static-pie.md)

## Build an extension bundle

```sh
./tools/container tools/build-extension arena
```

The command audits two reproducible builds and publishes the
startup object, `libopenasm-extension.a`, generated C declarations in
`include/`, and a source and artifact manifest under
`build/extensions/arena/current/`. The archive contains the core and
the selected package's declared dependency closure. Use the bundle's
startup object and archive together with the same static link order.
Package behavior has a separate gate. [Extension workflow](docs/cookbook/specifications.md#extension-package-scaffolding)

## Verification and scope

Run the named gates for the capability you need. For example, the
runtime smoke gate runs assembly and compiler-built test programs,
the local-time gate checks TZif and POSIX zone rules, and the
HTTP gate tests the assembly server and parser on loopback.

```sh
./tools/container make phase1 phase6-zone phase10-http
tools/queue status
```

The scoped gates cover core memory and strings, allocation, byte and
wide stdio, floating conversion and math, Linux files and process
control, threads, C and C.UTF-8, and networking. Calendar support
includes `localtime`, `localtime_r`, and `mktime` with TZif files
and POSIX `TZ` rules. The application suites cover pinned BusyBox
applets, Lua, zlib, and SQLite workloads. The exact scopes and
exceptions are recorded with the gates and their evidence in
`build/evidence/`. [Verification cookbook](docs/cookbook/verification.md) ·
[Time and zone ABI](docs/adr/0007-linux-files-process-signal-time.md#time-and-zone-data)

Whole-project production and release qualification is pending.
It requires fresh per-function evidence, the remaining exhaustive
binary32 campaigns, broader old/current-kernel and seccomp coverage,
the pinned LTP and gnulib subsets, and remaining performance gates.
Extension verification is tracked separately for each package and its
dependencies. [Roadmap](docs/plan.md) ·
[Nightly and tagged verification](docs/cookbook/verification.md#nightly-and-tagged-verification)

Licensed under the MIT License.
