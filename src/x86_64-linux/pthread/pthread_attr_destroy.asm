; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_attr_destroy
; header: pthread.h
; prototype: int pthread_attr_destroy(pthread_attr_t *attr)
; standard: POSIX.1-2024 XSH pthread_attr_destroy
; deps: -
; errno: EINVAL
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-attributes
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Invalidate an initialized attribute object without affecting threads previously created from it.
; semantics: Return zero on success or a positive error number. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_attr_destroy:function

section .text.pthread_attr_destroy alloc exec nowrite progbits
pthread_attr_destroy:
    test rdi, rdi
    jz .invalid
    cmp dword [rdi], 0x4f415448
    jne .invalid
    mov qword [rdi], 0
    xor eax, eax
    ret
.invalid:
    mov eax, 22                   ; EINVAL
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
