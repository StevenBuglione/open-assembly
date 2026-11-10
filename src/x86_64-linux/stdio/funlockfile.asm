; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: funlockfile
; header: stdio.h
; prototype: void funlockfile(FILE *stream)
; standard: POSIX.1-2024 XSH funlockfile
; deps: __errno_location
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:stream-ownership
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Release one level of explicit stream ownership by its current owner.
; semantics: Release the stream lock when the depth becomes zero. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global funlockfile:function
extern __al_stream_unlock:function

section .text.funlockfile alloc exec nowrite progbits
funlockfile:
    sub rsp, 8
    call __al_stream_unlock
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
