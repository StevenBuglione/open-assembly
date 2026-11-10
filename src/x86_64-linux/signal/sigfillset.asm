; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: sigfillset
; header: signal.h
; prototype: int sigfillset(sigset_t *set)
; standard: POSIX.1-2024 XSH sigfillset
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-signal-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Initialize the low word with all 64 Linux signal bits set and clear remaining public bytes.
; semantics: Return zero and preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global sigfillset:function
extern __al_sigset_publish:function

section .text.sigfillset alloc exec nowrite progbits
sigfillset:
    push rbp
    mov rbp, rsp
    mov rsi, -1
    call __al_sigset_publish
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
