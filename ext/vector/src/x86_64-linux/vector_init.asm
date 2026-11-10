; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: vector_init
; header: vector.h
; prototype: int vector_init(size_t state[5], size_t element_size, size_t alignment)
; standard: Extension ABI vector
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:arena-vector-model
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Initialize an empty caller-owned vector and record a nonzero element size and power-of-two alignment.
; semantics: Require element_size to be a multiple of alignment. Return -EINVAL on invalid arguments.
; semantics: Preserve state on failure and preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global vector_init:function

section .text.vector_init alloc exec nowrite progbits
vector_init:
    test rdi, rdi
    jz .invalid
    test rsi, rsi
    jz .invalid
    test rdx, rdx
    jz .invalid
    lea rax, [rdx - 1]
    test rdx, rax
    jnz .invalid
    test rsi, rax
    jnz .invalid
    mov qword [rdi], 0
    mov qword [rdi + 8], 0
    mov qword [rdi + 16], 0
    mov [rdi + 24], rsi
    mov [rdi + 32], rdx
    xor eax, eax
    ret
.invalid:
    mov eax, -22                ; EINVAL
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
