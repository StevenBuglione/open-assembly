# Optional static PIE startup

Status: proposed, scoped to x86-64 Linux and the pinned GNU linker.

The existing `runtime` target and `crt1.o` remain the default static
non-PIE entry. The opt-in `runtime-pie` target supplies `crt1-pie.o`
with a separate `__al_pie_entry` entry point. Compile linked C test
objects with `-fPIE`. Link through GNU ld with `-static -pie
--no-dynamic-linker -e __al_pie_entry -z noexecstack -z separate-code
-z relro -z now -z text`. The resulting `ET_DYN` binary has no
interpreter or dependency on a shared object. Linux maps the image
before the entry point runs. [GNU ld options](https://sourceware.org/binutils/docs/ld/Options.html) · [Linux ELF loading](https://raw.githubusercontent.com/torvalds/linux/master/fs/binfmt_elf.c)

The alternative entry computes the load bias from the GNU
`__ehdr_start` anchor. The self-relocator validates the program headers
and bounded dynamic table before reading relocation metadata. The
initial scope supports unpacked `Elf64_Rela` with symbol index zero and
type `R_X86_64_RELATIVE`. Targets are increasing, aligned, writable
file-backed slots outside the dynamic table. The relocation table is
read-only, and every addend belongs to the image range. No external
symbol lookup, packed relocations, or text relocations are supported.
[ELF relocation records](https://gabi.xinuos.com/elf/06-reloc.html) · [AMD64 psABI](https://gitlab.com/x86-psABIs/x86-64-ABI/-/raw/master/x86-64-ABI/low-level-sys-info.tex)

After validating the complete table, the runtime applies
`load_bias + addend` to each relocation slot, seals the GNU RELRO
pages with the raw kernel boundary, and records the load bias for the
TLS template address. It then transfers control to the ordinary
`_start` with the original kernel stack. TLS initialization, including
the initial thread's copy of pointer-valued data, occurs after
relocation. The stored bias starts at zero for the default static
`ET_EXEC` path. A rejected PIE terminates before TLS or application
initialization.

`tools/elf-audit --static-pie` explicitly selects the interpreter-free
PIE audit. It checks the actual program headers, dynamic records, and
relocation bytes, including that addends reference mapped image ranges.
The existing audit default continues to require static `ET_EXEC`.
The initial verification includes writable and RELRO pointers,
initialized TLS in the main thread and a worker, fresh load addresses
under native ASLR, and malformed relocation controls. CPU dispatch
and allocator changes have separate acceptance scopes.
