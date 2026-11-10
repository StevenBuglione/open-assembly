# Local production gate attempts

Each completed full core function gate appends a numbered record
under `build/attempts/<function>/`. Full production runs use the same
journal whether selected implicitly or with `--production`. Scoped
coverage, mutation, stub and fuzz runs, milestone gates and package
gates keep their own evidence. Existing reports and fixture controls
do not create attempt records.

An attempt records its candidate and specification hashes, available
tool identities and pinned toolchain identity, report hash, result and
failure reason. A failure counts only when the gate can attribute a
mismatch to the linked candidate and bind it to stable input and tool
identities. A tool failure, missing harness, ambiguous crash, unresolved
coverage or mutation requirement, or changed input is a harness
failure. Those attempts stay in the journal without advancing or
resetting the semantic failure count. A completed full production
pass resets the count. Candidate source revisions do not reset it.

Three semantic failures suspend the function. The queue derives
`blocked` from the journal and identifies a missing
`docs/blocked/<name>.md`. Record the attempt numbers, observed failures
and next investigation in that note. A blocked full gate exits before
running the candidate. The note does not fabricate earlier attempts.
A maintainer can record a deliberate resume after writing the note.

```sh
tools/queue resume name --reason "Updated the independent reproducer"
```

Resume starts a new counting window and keeps the previous records.
The journal is local to the checkout's build directory. A lock
serializes same-function invocations and publications are atomic.
Legacy reports with no classified attempt are not counted.
