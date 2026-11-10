; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_mutexattr_gettype
; header: pthread.h
; prototype: int pthread_mutexattr_gettype(const pthread_mutexattr_t *restrict attr, int *restrict type)
; standard: POSIX.1-2024 XSH pthread_mutexattr_gettype
; deps: -
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-mutex
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the initialized object's mutex type.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_mutexattr_gettype:function

section .text.pthread_mutexattr_gettype alloc exec nowrite progbits
pthread_mutexattr_gettype:
    test rdi, rdi
    jz .invalid
    cmp dword [rdi], 0x4f414d41
    jne .invalid
    test rsi, rsi
    jz .invalid
    mov eax, [rdi + 4]
    mov [rsi], eax
    xor eax, eax
    ret
.invalid:
    mov eax, 22
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
