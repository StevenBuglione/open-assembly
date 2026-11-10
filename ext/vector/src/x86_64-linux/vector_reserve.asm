; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: vector_reserve
; header: vector.h
; prototype: int vector_reserve(size_t *restrict state, size_t *restrict arena_state, size_t capacity)
; standard: Extension ABI vector
; deps: arena_alloc, memmove
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:arena-vector-model
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Grow initialized state to exactly the requested capacity when necessary, preserving current elements.
; semantics: Return a negative error for null required arguments, a wrapping new extent or arena exhaustion. Preserve both states on failure and preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global vector_reserve:function
extern arena_alloc:function
extern memmove:function

section .text.vector_reserve alloc exec nowrite progbits
vector_reserve:
    test rdi, rdi
    jz .invalid
    cmp rdx, [rdi + 16]
    jbe .unchanged
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, [rbx]              ; the old arena block remains live
    mov r13, rdx
    mov rdi, rsi
    mov rax, r13
    mov rcx, [rbx + 24]
    mul rcx
    test rdx, rdx
    jnz .overflow
    mov rsi, rax
    mov rdx, [rbx + 32]
    mov rcx, rbx                ; arena publishes the pointer only on success
    call arena_alloc
    test eax, eax
    jnz .return
    mov rdx, [rbx + 8]
    test rdx, rdx
    jz .capacity
    imul rdx, [rbx + 24]
    mov rdi, [rbx]
    mov rsi, r12
    call memmove
.capacity:
    mov [rbx + 16], r13
    xor eax, eax
    jmp .return
.overflow:
    mov eax, -75                 ; EOVERFLOW
.return:
    pop r13
    pop r12
    pop rbx
    ret
.unchanged:
    xor eax, eax
    ret
.invalid:
    mov eax, -22                 ; EINVAL
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
