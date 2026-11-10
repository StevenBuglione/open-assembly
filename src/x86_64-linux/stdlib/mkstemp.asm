; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: mkstemp
; header: stdlib.h
; prototype: int mkstemp(char *template)
; standard: POSIX.1-2024 XSH mkstemp
; deps: strlen, __errno_location
; errno: EACCES, EEXIST, EINVAL, EIO, EMFILE, ENAMETOOLONG, ENOENT, ENOSPC, EROFS
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-temporary-file-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Require a writable template ending in six X characters before its terminating NUL.
; semantics: Replace the six placeholders with random alphanumeric bytes and create the file exclusively.
; semantics: Request owner-only mode 0600 and return an open read-write descriptor on success.
; semantics: Retry name collisions and interruptions while obtaining randomness. Preserve errno on success.
; semantics: Return -1 and set errno on failure. Restore the six placeholders after a failed name attempt.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global mkstemp:function
extern __al_mktemp:function

section .text.mkstemp alloc exec nowrite progbits
mkstemp:
    push rbp
    mov rbp, rsp
    xor esi, esi
    call __al_mktemp
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
