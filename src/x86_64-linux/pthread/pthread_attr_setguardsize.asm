; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_attr_setguardsize
; header: pthread.h
; prototype: int pthread_attr_setguardsize(pthread_attr_t *attr, size_t guardsize)
; standard: POSIX.1-2024 XSH pthread_attr_setguardsize
; deps: -
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-attributes
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Store the requested guard size in bytes. Zero disables the guard.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_attr_setguardsize:function

section .text.pthread_attr_setguardsize alloc exec nowrite progbits
pthread_attr_setguardsize:
    test rdi, rdi
    jz .invalid
    cmp dword [rdi], 0x4f415448
    jne .invalid
    mov [rdi + 16], rsi
    xor eax, eax
    ret
.invalid:
    mov eax, 22                   ; EINVAL
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
