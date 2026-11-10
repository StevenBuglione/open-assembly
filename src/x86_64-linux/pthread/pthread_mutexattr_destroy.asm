; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_mutexattr_destroy
; header: pthread.h
; prototype: int pthread_mutexattr_destroy(pthread_mutexattr_t *attr)
; standard: POSIX.1-2024 XSH pthread_mutexattr_destroy
; deps: -
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-mutex
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Invalidate an initialized mutex attribute object.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_mutexattr_destroy:function

section .text.pthread_mutexattr_destroy alloc exec nowrite progbits
pthread_mutexattr_destroy:
    test rdi, rdi
    jz .invalid
    cmp dword [rdi], 0x4f414d41
    jne .invalid
    mov qword [rdi], 0
    xor eax, eax
    ret
.invalid:
    mov eax, 22
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
