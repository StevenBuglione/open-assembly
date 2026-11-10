# Phase 4 stdio test oracles

The fixtures link freestanding C programs and the two assembly utilities
against the runtime archive. The gate verifies references and definitions
with `nm`, audits static ELF output, and runs each case with explicit
input bytes. It records source, tool and artifact identities alongside
native, QEMU and Valgrind observations.

| Oracle ID | Expected observations |
| --- | --- |
| `c17:byte-streams` | C17 §7.21.3–§7.21.5 and §7.21.7–§7.21.10. Linux `pread64` exposes exact file bytes independently. Check unsigned-byte input, partial elements, EOF/error indicators, line and block buffering, pushback, positioning, append, reopening, and closing. |
| `c17:integer-format` | C17 §7.21.6.1 and §7.21.6.3–§7.21.6.5. Compare exact bytes and counts for signed and unsigned lengths, flags, dynamic widths, precision, truncation, and all count-store lengths. Protected pages detect reads past a bounded nonterminated string. |
| `c17:integer-scan` | C17 §7.21.6.2 and §7.21.6.7–§7.21.6.14. Check signed and unsigned limits, widths, suppression, scansets, literal matching, assignment counts, and the remaining input byte. A short `%c` field must fail to complete the conversion. The fixture distinguishes failure from assignment success without using either host as the oracle for this edge. |
| `abi:sysv-amd64` | Compiler-built calls supply promoted integers, output pointers, and arguments crossing the register/stack boundary. Separate `va_list` helpers call every v-form. [AMD64 psABI](https://gitlab.com/x86-psABIs/x86-64-ABI) |
| `project:stdio-abi` | Check declared buffer timing, multiplication and count overflow, pointer formatting, unsupported conversion errors, and exit behavior. Normal exit flushes after callbacks. Immediate exit leaves pending output unflushed. [Phase 4 ABI](../../docs/adr/0005-stdio-varargs.md) |
| `posix:fflush-input` | Synchronize seekable input to its logical position and discard pending pushback. [POSIX fflush](https://pubs.opengroup.org/onlinepubs/9799919799/functions/fflush.html) |
| `linux:stdio-fault` | A test-only wrapper injects `EINTR`, limits one real request to force a short transfer, or reports `EIO`. The fixture verifies that the effect reached the intended path. A separate case counts any `lseek` when closing a pipe with unread buffered input. |
| `reference:utility-bytes` | Compare `cat` output byte for byte, including NUL and high-bit bytes. Count `wc` newlines, C-locale word transitions, and bytes independently. Cover explicit standard input, file operands, option termination, totals, and errors. |
| `diff:glibc`, `diff:musl` | Hosted builds of common cases use each pinned libc and assert the same defined results independently. |
| `suite:libc-test` | Compile unchanged upstream `scanf-bytes-consumed`, `scanf-nullbyte-char`, `scanf-match-literal-eof`, and `setvbuf-unget` regressions from the pinned MIT-licensed source. An adapter records any assertion failure independently of formatted output. [libc-test upstream](https://repo.or.cz/libc-test.git) |

C17 citations refer to ISO/IEC 9899:2018. [WG14 baseline with later edits marked](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)

The upstream subset uses Phase 4 interfaces. Cases requiring floating
point, wide characters, or process APIs belong to the corresponding
phases. Guard pages reveal accesses that cross protected boundaries.

```sh
./tools/container python3 tools/phase4.py
```
