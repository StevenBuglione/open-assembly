; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_mutex_trylock
; header: pthread.h
; prototype: int pthread_mutex_trylock(pthread_mutex_t *mutex)
; standard: POSIX.1-2024 XSH pthread_mutex_trylock
; deps: __errno_location
; errno: EAGAIN, EBUSY, EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-mutex
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Acquire without waiting. An owned nonrecursive mutex reports EBUSY.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_mutex_trylock:function
extern __al_mutex_acquire:function

section .text.pthread_mutex_trylock alloc exec nowrite progbits
pthread_mutex_trylock:
    sub rsp, 8
    mov esi, 1
    call __al_mutex_acquire
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
