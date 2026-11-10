; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_attr_getguardsize
; header: pthread.h
; prototype: int pthread_attr_getguardsize(const pthread_attr_t *restrict attr, size_t *restrict guardsize)
; standard: POSIX.1-2024 XSH pthread_attr_getguardsize
; deps: -
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-attributes
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the requested inaccessible guard size in bytes.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_attr_getguardsize:function

section .text.pthread_attr_getguardsize alloc exec nowrite progbits
pthread_attr_getguardsize:
    test rdi, rdi
    jz .invalid
    cmp dword [rdi], 0x4f415448
    jne .invalid
    test rsi, rsi
    jz .invalid
    mov rax, [rdi + 16]
    mov [rsi], rax
    xor eax, eax
    ret
.invalid:
    mov eax, 22                   ; EINVAL
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
