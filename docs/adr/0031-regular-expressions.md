# Regular expression compilation and matching

Regex_t records the subexpression count and owns an immutable
program. Regexec reports byte offsets in LP64 regoff_t values.
Its working state belongs to the call. REG_NOSUB leaves the
match array untouched. Regfree releases the compiled program.

The compiler parses basic or extended syntax into an indexed
expression tree and emits instructions for character matching,
branching, captures and repetition. The matcher tries start
positions from left to right and compares complete matches at
the first matching start. Repetition records input progress so
an empty subexpression cannot create an unbounded loop. The
matcher deduplicates identical instruction, input and capture
states. Equal full matches compare subexpression lengths in
characters and report offsets in bytes.

C and C.UTF-8 use the runtime's byte and scalar matching rules.
The bracket parser recognizes POSIX character classes and
single-character collating elements. Matching uses LC_CTYPE
from compilation, and REG_NEWLINE applies to dot, negated
brackets and line anchors. Intervals support bounds through 255.
BRE supports back-references and escaped alternation. Escaped
digits in ERE are literal. Invalid UTF-8 pattern bytes report
REG_BADPAT.

[POSIX regex functions](https://pubs.opengroup.org/onlinepubs/9799919799/functions/regcomp.html).
