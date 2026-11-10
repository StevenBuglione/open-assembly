; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_mutex_lock
; header: pthread.h
; prototype: int pthread_mutex_lock(pthread_mutex_t *mutex)
; standard: POSIX.1-2024 XSH pthread_mutex_lock
; deps: __errno_location
; errno: EAGAIN, EDEADLK, EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-mutex
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Acquire the mutex. Block when another thread owns it. Retry signal interruptions internally.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_mutex_lock:function
extern __al_mutex_acquire:function

section .text.pthread_mutex_lock alloc exec nowrite progbits
pthread_mutex_lock:
    sub rsp, 8
    xor esi, esi
    call __al_mutex_acquire
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
