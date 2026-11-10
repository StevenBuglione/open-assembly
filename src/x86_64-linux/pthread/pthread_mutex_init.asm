; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_mutex_init
; header: pthread.h
; prototype: int pthread_mutex_init(pthread_mutex_t *restrict mutex, const pthread_mutexattr_t *restrict attr)
; standard: POSIX.1-2024 XSH pthread_mutex_init
; deps: -
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-mutex
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Initialize an unlocked process-private mutex. A null attribute selects the normal type.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_mutex_init:function
extern __al_mutex_init:function

section .text.pthread_mutex_init alloc exec nowrite progbits
pthread_mutex_init:
    test rdi, rdi
    jz .invalid
    test rsi, rsi
    jz .initialize
    cmp dword [rsi], 0x4f414d41
    jne .invalid
    mov esi, [rsi + 4]
.initialize:
    sub rsp, 8
    call __al_mutex_init
    add rsp, 8
    ret
.invalid:
    mov eax, 22                   ; EINVAL
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
