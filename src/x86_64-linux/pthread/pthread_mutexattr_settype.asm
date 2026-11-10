; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_mutexattr_settype
; header: pthread.h
; prototype: int pthread_mutexattr_settype(pthread_mutexattr_t *attr, int type)
; standard: POSIX.1-2024 XSH pthread_mutexattr_settype
; deps: -
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-mutex
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Select normal, error-checking, or recursive ownership. Reject unknown values.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_mutexattr_settype:function

section .text.pthread_mutexattr_settype alloc exec nowrite progbits
pthread_mutexattr_settype:
    test rdi, rdi
    jz .invalid
    cmp dword [rdi], 0x4f414d41
    jne .invalid
    movsxd rsi, esi
    cmp rsi, 2
    ja .invalid
    mov [rdi + 4], esi
    xor eax, eax
    ret
.invalid:
    mov eax, 22
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
