; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_cond_wait
; header: pthread.h
; prototype: int pthread_cond_wait(pthread_cond_t *restrict cond, pthread_mutex_t *restrict mutex)
; standard: POSIX.1-2024 XSH pthread_cond_wait
; deps: pthread_mutex_lock, pthread_mutex_unlock, __errno_location
; errno: EAGAIN, EINVAL, EPERM
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-condition
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Register a wait, release the singly held mutex, and reacquire it before returning.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_cond_wait:function
extern __al_cond_wait:function

section .text.pthread_cond_wait alloc exec nowrite progbits
pthread_cond_wait:
    sub rsp, 8
    xor edx, edx
    mov rcx, -1
    call __al_cond_wait
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
