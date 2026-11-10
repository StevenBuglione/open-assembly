; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: vector_at
; header: vector.h
; prototype: int vector_at(const size_t *restrict state, size_t index, void **restrict result)
; standard: Extension ABI vector
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:arena-vector-model
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Publish a pointer to an existing indexed element. Return -ERANGE for an out-of-range index.
; semantics: Preserve result on failure and preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global vector_at:function

section .text.vector_at alloc exec nowrite progbits
vector_at:
    test rdi, rdi
    jz .invalid
    test rdx, rdx
    jz .invalid
    cmp rsi, [rdi + 8]
    jae .outside
    imul rsi, [rdi + 24]         ; every existing element fits in the buffer
    add rsi, [rdi]
    mov [rdx], rsi
    xor eax, eax
    ret
.invalid:
    mov eax, -22                 ; EINVAL
    ret
.outside:
    mov eax, -34                 ; ERANGE
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
