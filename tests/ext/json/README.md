# Independent JSON verification

The bounded APIs follow [the package contract](../../../ext/json/README.md)
and [RFC 8259](https://www.rfc-editor.org/rfc/rfc8259.html). Raw string
octets follow [RFC 3629](https://www.rfc-editor.org/rfc/rfc3629.html).
The directed cases include all byte substitutions at selected lexical
positions, truncated lexemes, duplicate object names, exact preorder
token spans, workspace arithmetic overflow and failure-preserved output.
The guard case puts the input, output and workspace beside inaccessible
pages. Parser memory-fault status 29 requires a signal during the named
candidate call. Faults elsewhere have a separate harness status.

The Python packet model builds lexical spans from anchored grammar
and checks strings through strict UTF-8 decoding and Python JSON
string decoding. It models document structure and parent indices
independently. Numeric spelling remains in the source span. A 64-byte
input packet selects a bounded document, offset and workspace limits.
A 240-byte result contains signed status, errno and all output words,
including canaries for untouched records.

The shared SysV state probe runs natively and under QEMU. Its nondefault
x87 state control exceeds Memcheck emulation. Memcheck still exercises
the semantic, packet and guard cases. The separate pinned
JSONTestSuite gate covers unchanged definite acceptance and rejection
cases on all three backends.
