; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_cond_timedwait
; header: pthread.h
; prototype: int pthread_cond_timedwait(pthread_cond_t *restrict cond, pthread_mutex_t *restrict mutex, const struct timespec *restrict abstime)
; standard: POSIX.1-2024 XSH pthread_cond_timedwait
; deps: pthread_mutex_lock, pthread_mutex_unlock, __errno_location
; errno: EAGAIN, EINVAL, EPERM, ETIMEDOUT
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-condition
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Wait until signaled or an absolute deadline on the configured clock. Reacquire the singly held mutex even on timeout.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_cond_timedwait:function
extern __al_cond_wait:function

section .text.pthread_cond_timedwait alloc exec nowrite progbits
pthread_cond_timedwait:
    test rdx, rdx
    jz .invalid
    sub rsp, 8
    mov rcx, -1
    call __al_cond_wait
    add rsp, 8
    ret
.invalid:
    mov eax, 22
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
