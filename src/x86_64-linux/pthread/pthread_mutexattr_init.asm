; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_mutexattr_init
; header: pthread.h
; prototype: int pthread_mutexattr_init(pthread_mutexattr_t *attr)
; standard: POSIX.1-2024 XSH pthread_mutexattr_init
; deps: -
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-mutex
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Initialize process-private attributes with the default mutex type.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_mutexattr_init:function

section .text.pthread_mutexattr_init alloc exec nowrite progbits
pthread_mutexattr_init:
    test rdi, rdi
    jz .invalid
    mov qword [rdi], 0x4f414d41
    mov qword [rdi + 8], 0
    xor eax, eax
    ret
.invalid:
    mov eax, 22
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
