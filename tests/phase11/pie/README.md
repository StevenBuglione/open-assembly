# Independent static PIE startup checks

Run `./tools/container make phase11-static-pie`. The same C fixture runs
with both startup modes. It loads an exported immutable pointer slot from
RELRO, changes an exported writable pointer slot, and calls through a
relocated code pointer. It checks pointer-valued and over-aligned initialized
thread-local storage before creating threads and verifies each of two workers
starts with independent initial values while the main thread retains its own
modifications. A plain NASM main supplies a separate zero-relocation ELF.

The runner inspects actual ELF relocation records and native mappings, checks
two ASLR load biases, and tests malformed RELA and TLS controls. Native Linux,
QEMU and Memcheck exercise the semantic fixtures. The startup contract and
supported relocation classes are described in ADR 0028.

[ELF relocation records](https://gabi.xinuos.com/elf/06-reloc.html)
[AMD64 psABI](https://gitlab.com/x86-psABIs/x86-64-ABI/-/raw/master/x86-64-ABI/low-level-sys-info.tex)
