; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_mutex_clocklock
; header: pthread.h
; prototype: int pthread_mutex_clocklock(pthread_mutex_t *restrict mutex, clockid_t clock, const struct timespec *restrict abstime)
; standard: POSIX.1-2024 XSH pthread_mutex_clocklock
; deps: __errno_location
; errno: EAGAIN, EDEADLK, EINVAL, ETIMEDOUT
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-mutex
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Select CLOCK_REALTIME or CLOCK_MONOTONIC for the absolute deadline.
; semantics: Acquire an immediately available mutex without consulting the deadline.
; semantics: Do not return EINTR. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_mutex_clocklock:function
extern __al_mutex_acquire:function

section .text.pthread_mutex_clocklock alloc exec nowrite progbits
pthread_mutex_clocklock:
    movsxd rsi, esi
    cmp esi, 1                    ; CLOCK_MONOTONIC
    ja .invalid
    sub rsp, 8
    add esi, 2                    ; timed, realtime or monotonic
    call __al_mutex_acquire
    add rsp, 8
    ret

.invalid:
    mov eax, 22                   ; EINVAL
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
