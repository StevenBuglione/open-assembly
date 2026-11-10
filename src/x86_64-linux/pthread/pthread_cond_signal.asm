; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_cond_signal
; header: pthread.h
; prototype: int pthread_cond_signal(pthread_cond_t *cond)
; standard: POSIX.1-2024 XSH pthread_cond_signal
; deps: -
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-condition
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Select and wake one registered waiter, when present.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_cond_signal:function
extern __al_cond_wake:function

section .text.pthread_cond_signal alloc exec nowrite progbits
pthread_cond_signal:
    sub rsp, 8
    xor esi, esi
    call __al_cond_wake
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
