; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_attr_init
; header: pthread.h
; prototype: int pthread_attr_init(pthread_attr_t *attr)
; standard: POSIX.1-2024 XSH pthread_attr_init
; deps: -
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-attributes
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Initialize a reusable thread attribute object with joinable state, a 1 MiB stack, and one page of guard storage.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_attr_init:function
extern __al_tls_template:data

section .text.pthread_attr_init alloc exec nowrite progbits
pthread_attr_init:
    test rdi, rdi
    jz .invalid
    mov qword [rdi], 0x4f415448
    mov qword [rdi + 8], 1048576
    mov rax, [rel __al_tls_template + 48]
    mov [rdi + 16], rax
    mov qword [rdi + 24], 0
    xor eax, eax
    ret
.invalid:
    mov eax, 22                   ; EINVAL
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
