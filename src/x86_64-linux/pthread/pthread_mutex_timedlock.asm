; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_mutex_timedlock
; header: pthread.h
; prototype: int pthread_mutex_timedlock(pthread_mutex_t *restrict mutex, const struct timespec *restrict abstime)
; standard: POSIX.1-2024 XSH pthread_mutex_timedlock
; deps: __errno_location
; errno: EAGAIN, EDEADLK, EINVAL, ETIMEDOUT
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-mutex
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Use an absolute CLOCK_REALTIME deadline when acquisition requires waiting.
; semantics: Acquire an immediately available mutex without consulting the deadline.
; semantics: Do not return EINTR. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_mutex_timedlock:function
extern __al_mutex_acquire:function

section .text.pthread_mutex_timedlock alloc exec nowrite progbits
pthread_mutex_timedlock:
    sub rsp, 8
    mov rdx, rsi
    mov esi, 2                    ; timed, CLOCK_REALTIME
    call __al_mutex_acquire
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
