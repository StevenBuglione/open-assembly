# Function specifications

Phase 0 includes the specification, inventory, and fixture verification
workflow. The only authored function specification is `strlen`; no
production library function is implemented or verified.

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

Unknown fields, duplicate values and handwritten status are errors.
Use [`spec/deviations.toml`](../../spec/deviations.toml) for deliberate
choices that differ from musl when C17 leaves behavior open. Its
`[[deviations]]` rows name the `function` and `standard` and explain the
`choice` and `reason`. Phase 0 has no recorded deviations.

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

The initial POSIX target is the
[POSIX.1-2024 `<unistd.h>` bootstrap subset](https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/unistd.h.html):
`_exit`, `close`, `read`, `write`, `size_t`, and `ssize_t`. Additional
POSIX APIs must be scoped and added in later milestones. In this inventory,
1 of 505 named functions has a spec, and none has a production
implementation. Cataloging a name does not implement the function or
define any type layout, macro value, or conformance claim.

## Generated files

Run `tools/gen` to refresh `include/asm/<header>.inc`,
`build/include/c/<header>.h`, and [the API index](../api-index.md). Only
headers with authored function specs are generated. The C declarations are
ignored test inputs; they rely on the test compiler's `<stddef.h>` and do
not replace the host libc headers as a whole. Other type layouts and the
full public C header surface are future work.

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

`tools/queue status [FUNCTION]` reports `todo` for inventoried functions
without a production source and `implemented` for a function with a
matching source and generated header under `src/x86_64-linux/`.
`tools/queue next` selects the first authored `todo` with all function
dependencies verified. In Phase 0 only a dependency-free function can be
eligible. The queue is advisory; starting a production implementation
still requires the next milestone.

A `build/evidence/<function>.json` Phase 0 fixture manifest records input
hashes, tool identity, and individual outcomes. The queue reports stale
and malformed evidence separately. Even a passing and current fixture
cannot verify a production function or unlock its dependents. The complete
production evidence producer and the failed-attempt history for computed
`blocked` status are pending. Phase 0 rejects production verification
claims.
