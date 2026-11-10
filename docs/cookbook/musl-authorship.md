# Nightly musl authorship review

Run `./tools/container make scan-musl-authorship`. The scan compares the
actual shipped public runtime object for each symbol to the same exported
text symbol in the pinned musl 1.2.6 static archive. It verifies the
archive byte hash and compares every matching definition, including
members with the same name. An alias can use the disassembler's preferred
label only when the ELF symbol table places both at the same section
address. Symbols absent from musl and pairs shorter than 12 instructions
are recorded separately.

The scan ignores padding and CET entry markers. It renames general and
vector registers in first-use order, retains their widths and stack
register roles, and replaces direct branch addresses with directions.
Instruction mnemonics, memory shapes and other immediate values remain in
the comparison. The report includes each normalized fingerprint, the
matching instruction ratio and the longest contiguous match.

A pair of at least 12 instructions is flagged for review when its
normalized sequences match exactly, when at least 90% of the instructions
match with an 8-instruction contiguous run, or when a 20-instruction
contiguous run covers at least 75% of the shorter sequence and the total
match is at least 65%. Reviewers can inspect the named source and both
identified objects. Similarity is a review signal and does not establish
a code's provenance. A passing scan means the comparison and controls
ran. The review queue lists findings separately.

The copied-code negative control relocates the pinned musl `strlen`
object in a temporary build directory and requires a normalized exact
match. The positive control assembles a distinct test-only `strlen`
and requires it to clear the same thresholds. Neither artifact enters
the shipped archive. `build/evidence/musl-authorship.json` records the
scan and `build/evidence/musl-authorship-review.json` binds the review
queue to that report's SHA-256.
