# Lua 5.4.9 static runtime gate

Run `./tools/container make phase6-lua`. The shared pinned Nix environment
provides the official Lua 5.4.9 source and matching test archives. The
gate checks both digests and the upstream test runner and license document.
Lua is MIT-licensed. Copyright © 1994–2026 Lua.org, PUC-Rio.

The upstream build uses its unmodified makefile and sources with
`LUA_USE_POSIX` and the generated project C headers. Two isolated builds
must produce identical Lua object files, archives, and linked executables.
The linker uses the project startup and archive. The ELF audit and link map
verify the static executable and the origin of its selected Lua and
runtime symbols, including file I/O, shell, time, longjmp, and math.

Native, QEMU user mode, and Memcheck each extract a fresh official test
tree and run `lua -e '_U=true' all.lua`. The upstream basic mode selects
the portable tests and emits `final OK !!!` at completion. The gate
records the version, status, timing and output for each backend.

The executable supports Lua source modules and its built-in C libraries.
This static configuration leaves dynamic C module loading disabled.
A directed `package.loadlib` check verifies Lua's explicit unavailable
result on each backend. Upstream complete and internal C tests are
outside the portable suite's scope.

[Lua source archive](https://www.lua.org/ftp/lua-5.4.9.tar.gz) ·
[Lua portable suite](https://www.lua.org/tests/) ·
[Lua MIT license](https://www.lua.org/license.html)
