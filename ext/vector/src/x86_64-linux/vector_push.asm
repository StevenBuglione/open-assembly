; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: vector_push
; header: vector.h
; prototype: int vector_push(size_t *restrict state, size_t *restrict arena_state, const void *element)
; standard: Extension ABI vector
; deps: vector_reserve, memmove
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:arena-vector-model
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Append one element. Grow capacity geometrically in the caller-owned arena when needed.
; semantics: Return a negative error for invalid arguments, wrapping extent or arena exhaustion. Preserve both states on failure and preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global vector_push:function
extern vector_reserve:function
extern memmove:function

section .text.vector_push alloc exec nowrite progbits
vector_push:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    test rbx, rbx
    jz .invalid
    test r13, r13
    jz .invalid
    mov r14, [rbx + 8]
    lea r15, [r14 + 1]         ; a valid backing extent leaves this representable
    cmp r14, [rbx + 16]
    jb .append
    mov rdx, r15
    test r14, r14
    jz .reserve
    mov rdx, r14
    add rdx, rdx
    sbb rax, rax
    or rdx, rax                ; saturate doubling at SIZE_MAX
.reserve:
    mov [rsp], rdx
    mov rdi, rbx
    mov rsi, r12
    call vector_reserve
    test eax, eax
    jz .append
    cmp eax, -28               ; ENOSPC
    je .try_exact
    cmp eax, -75               ; EOVERFLOW
    jne .return
.try_exact:
    cmp r15, [rsp]
    je .return
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r15
    call vector_reserve
    test eax, eax
    jnz .return
.append:
    mov rdx, [rbx + 24]
    mov rdi, r14
    imul rdi, rdx
    add rdi, [rbx]
    mov rsi, r13
    call memmove
    mov [rbx + 8], r15
    xor eax, eax
    jmp .return
.invalid:
    mov eax, -22               ; EINVAL
.return:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
