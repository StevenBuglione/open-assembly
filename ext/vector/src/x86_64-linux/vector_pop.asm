; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: vector_pop
; header: vector.h
; prototype: int vector_pop(size_t *restrict state, void *result)
; standard: Extension ABI vector
; deps: memmove
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:arena-vector-model
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Remove the last element, copying it to a nonnull result. Return -ENOENT if empty.
; semantics: Preserve state and result on failure and preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global vector_pop:function
extern memmove:function

section .text.vector_pop alloc exec nowrite progbits
vector_pop:
    test rdi, rdi
    jz .invalid
    mov rax, [rdi + 8]
    test rax, rax
    jz .empty
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rdi
    lea r12, [rax - 1]
    test rsi, rsi
    jz .remove
    mov rdi, rsi
    mov rdx, [rbx + 24]
    mov rsi, r12
    imul rsi, rdx
    add rsi, [rbx]
    call memmove
.remove:
    mov [rbx + 8], r12
    xor eax, eax
    add rsp, 8
    pop r12
    pop rbx
    ret
.invalid:
    mov eax, -22                 ; EINVAL
    ret
.empty:
    mov eax, -2                  ; ENOENT
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
