# Function specifications

The specification, inventory, and fixture workflow established in Phase 0
also covers the production bootstrap functions. The
[runtime ABI](../adr/0002-runtime-abi.md) defines the entry, thread block,
and private syscall interfaces shared by those functions.

A function is described once, in
`spec/functions/<header-without-.h>/<function>.toml`. For example, the
specification for `<string.h>`'s `strlen` is
[`spec/functions/string/strlen.toml`](../../spec/functions/string/strlen.toml).
Names are unique across function specifications, and every function must
already appear in the inventory for its declared header.

Required fields:

| Field | Meaning |
| --- | --- |
| `name`, `header` | C identifier and standard header path. |
| `prototype` | One line with a named C function prototype, without a semicolon. Use `(void)` for no arguments. The parser checks a limited declarator syntax; type correctness still requires compiling tests. Complex return declarators, such as a function returning a function pointer, need a future schema extension. |
| `standard` | Nonempty list of references such as `C17 7.24.6.3` or `POSIX.1-2024 XSH read`. Use section references, not standard prose. |
| `deps`, `errno` | Function names and error identifiers, respectively. Use empty arrays when neither applies. A dependency may be inventoried before it has a specification; it stays unmet. Unknown dependencies and cycles are errors. |
| `mt_safe`, `as_safe` | Boolean thread safety and async signal safety requirements. |
| `oracles` | Nonempty list with identifiers such as `diff:glibc`, `suite:libc-test/strtol`, `reference:byte-count`, or `vectors:decimal`. |
| `semantics` | Nonempty list of single-line requirements written for independent test authors. Include the input contract and relevant edge cases. |
| `provenance` | `"original"` or a source record described below. |
| `abi.narrow_args`, `abi.variadic` | An array of incoming SysV integer register and extension pairs, e.g. `["edi:s32", "sil:u8"]`, and a boolean agreeing with the prototype's ellipsis. The schema cross-checks builtin types with known incoming registers. Use explicit metadata for opaque typedefs and aggregates; review plain char signedness for the target. |
| `abi.noreturn` | Optional boolean, defaulting to `false`. Use `true` for a prototype with `_Noreturn`; the checker uses it to validate nonreturning functions. |

Unknown fields, duplicate values and handwritten status are errors.
Use [`spec/deviations.toml`](../../spec/deviations.toml) for deliberate
choices that differ from musl when C17 leaves behavior open. Its
`[[deviations]]` rows name the `function` and `standard` and explain the
`choice` and `reason`.

## Inventory scope

[`spec/inventory.toml`](../../spec/inventory.toml) catalogs names from all
29 ISO C17 library headers using clause 7 of the
[WG14 C17 baseline with later proposed edits marked](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf).
The clause lists and synopses take priority over the Annex B summary. For
example, the inventory includes both `alignas` and `alignof` and counts
`setjmp` as a macro because C17 does not require a separately callable
symbol. The inventory tracks separately specified generic atomic operations
as their own kind.

| C17 item kind | Count |
| --- | ---: |
| Functions | 501 |
| Macros | 478 |
| Types | 113 |
| Generic atomic operations | 22 |
| Enumeration constants | 14 |
| Standard pragmas | 3 |
| Open-width families | 50 |

Counts are per header and include conditional names. For example,
`size_t` occurs in every header that explicitly provides it; declarations
in a transitively included header are counted under that header. The
catalog names each `float`, `double`, and `long double` function, every
atomic fetch operation, and the C17 integer width variants for 8, 16, 32,
and 64 bits. Conditional `{N}` patterns represent other positive decimal
widths if provided. Those patterns count once each and do not claim support
for arbitrary widths. Named optional facilities, such as the complex,
atomic, and threads APIs, and feature-dependent macros are grouped by
availability. The catalog excludes Annex K, decimal extensions, compiler
predefines, reserved or implementation-defined names that the standard
does not enumerate, and future library directions.

The named POSIX subset covers `_exit`, `close`, `read`, `write`, `size_t`,
`ssize_t`, the three standard file descriptor macros, and the `environ`
object. [POSIX.1-2024 unistd.h](https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/unistd.h.html)

The allocator and environment milestone adds `posix_memalign`, `putenv`,
`setenv`, and `unsetenv`. The runtime ABI entries `__errno_location` and
`__stack_chk_fail` have separate inventory groups. The API index lists
authored function specifications. [POSIX.1-2024 stdlib.h](https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/stdlib.h.html) · [API index](../api-index.md)

The first file slice adds `open`, `openat`, `creat`, `lseek`, `dup`,
`dup2`, `pipe`, `mkdir`, `rmdir`, and `unlink`. The generator reads
Linux flag values, seek origins, mode bits, and syscall numbers from
`spec/types/linux-x86_64-files.toml`. [Phase 6 ABI](../adr/0007-linux-files-process-signal-time.md)

## Generated files

Run `tools/gen` to refresh `include/asm/<header>.inc`,
`build/include/c/<header>.h`, and [the API index](../api-index.md). Only
headers with authored function specs are generated. The C declarations are
ignored test inputs; they rely on the test compiler's `<stddef.h>` and use
the Linux UAPI `<asm/errno.h>` for target errno values. The generated
`errno` lvalue calls `__errno_location`; `ssize_t` is `long` on this target.
The generated C and NASM unistd declarations share the file descriptor
constants. Full public C headers are future work.

`tools/gen --check` compares the expected path set and exact bytes without
editing files. From a fresh checkout, run `tools/gen --test-headers` first
to create just the ignored C headers. To check the tracked artifacts alone,
use `tools/gen --check --tracked-only`. The generator refuses to replace
files that lack its marker.

For an assembly implementation or test fixture that declares the
specified public function, generate the leading comment block with
`tools/gen --comment-header strlen` and copy it exactly. The checker
validates that block and the exported name. The block records the
contract, ABI metadata, and provenance.

## Provenance and evidence

For a permitted external algorithm, supply a provenance table with
`origin`, the canonical upstream `url`, immutable `revision`, normalized
`upstream_path`, the applicable permissive `license`, and a repository
`notice` path of the form `spec/provenance/<function>.txt` containing the
applicable upstream notice. Git sources use full commit IDs; Netlib fdlibm
uses the SHA-256 of the source file. Use the origin allowlist in
[`tools/spec.py`](../../tools/spec.py). `tools/provenance --check` checks
the record and any matching production source header. Maintainers still
review the upstream file and license and check authorship. An execution
oracle such as glibc is not an algorithm source.

`tools/queue status [FUNCTION]` reports `todo` when a function has no
production source, `implemented` when a source and generated header are
present, and `verified` after a fresh production-function pass.
`tools/queue next` selects the first authored `todo` with all function
dependencies verified.

The queue reports stale and malformed evidence separately. Phase 0 fixture
reports and Phase 1 and Phase 3 milestone reports have separate scopes.
Only per-function production reports can unlock dependencies. Computed
failure history and `blocked` status are pending.

## Extension package scaffolding

An extension declares its namespace, independent oracle, stability and
package dependencies in `ext/<package>/package.toml`. Public function
specifications use the existing ABI and provenance schema. The prefix
`<package>_` is added to the function's short name. Function dependencies
must name a specified runtime function or a function in the same package
or a declared dependency package. The loader rejects dependency cycles
and symbolic links in package input paths.

```sh
tools/new-package word_math --oracle reference:unsigned-minimum
tools/new-function word_math clamp_u32 \
  --prototype 'unsigned int word_math_clamp_u32(unsigned int value, unsigned int ceiling)' \
  --narrow-arg edi:u32 --narrow-arg esi:u32 \
  --mt-safe --as-safe \
  --semantics 'Return the smaller unsigned value.'
tools/gen
tools/gen --comment-header word_math_clamp_u32
```

Use the generated comment in the hand-authored NASM source at
`ext/word_math/src/x86_64-linux/word_math_clamp_u32.asm`. Generation also
updates the package include, test declarations and API index. Keep the
independently authored C fixtures and their manifest under
`tests/ext/word_math/`. Every fixture names the package oracle and each
public entry point needs a generated-stub rejection. An extension can use
an external suite or an independent model under the protected oracle path.

Run `./tools/container tools/extension-gate word_math` after writing the
implementation and tests. The scope uses reproducible static links, ABI and
source checks, native/QEMU/Memcheck cases, and the generated stub controls.
An empty scaffold cannot pass. Use `--require-production` with
`tests/ext/<package>/production.toml` to require direct SysV ABI, all
conditional edges observed under QEMU, at least 90 percent NASM mutation
rejection, and at least 60 seconds of differential packets. Each function
names a Python model under `tests/oracle/<package>/` and declares the fixed
request and result record sizes. The evidence binds the model and exact
candidate bytes. See the disposable word_math production fixture for the
manifest format. Pinned suite adapters remain pending.

Before declaring a package stable, review and add its ABI baseline at
`tests/oracle/<package>/extension-abi.toml`. The protected file freezes
the public function set, each C declaration's tokens and its register
extension, variadic and nonreturning metadata. The target is
`x86_64-linux-sysv`. Every declaration appears once in `[[function]]`
with `name`, `prototype`, `narrow_args`, `variadic`, and `noreturn`.
Generation rejects a missing baseline, a declaration change, or removal
or downgrade of a frozen package.

Declare each public record as a namespaced `[[layout]]` with `name`,
`size`, `align`, and an ordered `member` array. Each member has `name`,
`type`, and a byte `offset`. Use `count` for an inline array. For a package
with no records, set `layout = []` before the function tables. The ABI
baseline begins with `schema_version = 1`, `target`, and `package`.
This record entry declares `struct packet_view` in the package header.

```toml
[[layout]]
name = "packet_view"
size = 16
align = 8
member = [
  {name = "data", type = "const unsigned char *", offset = 0},
  {name = "length", type = "size_t", offset = 8},
]
```

The package gate and publisher compile static assertions with pinned
GCC and Clang against the generated header. The checks cover function
types and each declared record's size, alignment, member offsets and
member types. Evidence binds the baseline, header, probe and compiler
objects. Changes that require a different frozen ABI can use a new
package namespace.

Run `./tools/container tools/build-extension word_math` to produce a
static package for an application. The command audits two isolated builds
and publishes their matching `crt1.o`, `libopenasm-extension.a`, and
generated C headers in `build/extensions/word_math/current/`. The archive
includes the core and the declared extension dependency closure. The
hash-addressed bundle also contains a manifest with source and artifact
identities. The `current` link is updated only after a complete build.
Run `extension-gate` separately for behavioral evidence.

A full smoke control is available in a disposable checkout through
`./tools/container tests/tooling/extensions/setup.sh`. It exercises both
rejections and an independently tested scalar package.
