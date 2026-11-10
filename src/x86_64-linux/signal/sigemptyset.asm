; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: sigemptyset
; header: signal.h
; prototype: int sigemptyset(sigset_t *set)
; standard: POSIX.1-2024 XSH sigemptyset
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-signal-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Initialize all bytes of the public mask to zero and return zero.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global sigemptyset:function
extern __al_sigset_publish:function

section .text.sigemptyset alloc exec nowrite progbits
sigemptyset:
    push rbp
    mov rbp, rsp
    xor esi, esi
    call __al_sigset_publish
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
