; Add signed scaled bignums at rdi/rsi, powers rdx/rcx, sign mask r8 and precision r9.
bits 64
default rel

global __al_complex_signed_sum:function
extern __al_big_bits:function
extern __al_big_right_sticky:function
extern __al_complex_align:function
extern __al_big_add:function
extern __al_big_cmp:function
extern __al_big_sub:function
extern __al_big_copy:function

section .text.__al_complex_signed_sum alloc exec nowrite progbits
__al_complex_signed_sum:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 64
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov r15d, r8d
    mov [rsp], r9
    cmp qword [r12], 0
    je .left
    cmp qword [rbx], 0
    je .right
    mov rdi, rbx
    call __al_big_bits
    add rax, r13
    mov [rsp + 8], rax
    mov rdi, r12
    call __al_big_bits
    add rax, r14
    cmp rax, [rsp + 8]
    jge .cutoff
    mov rax, [rsp + 8]
.cutoff:
    sub rax, [rsp]
    mov [rsp + 16], rax
    cmp r13, rax
    jge .trim_right
    mov rsi, rax
    sub rsi, r13
    mov rdi, rbx
    call __al_big_right_sticky
    mov r13, [rsp + 16]
.trim_right:
    cmp r14, [rsp + 16]
    jge .check_left
    mov rsi, [rsp + 16]
    sub rsi, r14
    mov rdi, r12
    call __al_big_right_sticky
    mov r14, [rsp + 16]
.check_left:
    cmp qword [r12], 0
    je .left
    cmp qword [rbx], 0
    je .right
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    mov rcx, r14
    call __al_complex_align
    mov r13, rax
    mov r14, rax
    mov eax, r15d
    shr eax, 1
    xor eax, r15d
    test eax, 1
    jnz .difference
    mov rdi, rbx
    mov rsi, r12
    call __al_big_add
    jmp .left
.difference:
    mov rdi, rbx
    mov rsi, r12
    call __al_big_cmp
    test eax, eax
    jz .zero
    js .right_minus
    mov rdi, rbx
    mov rsi, r12
    call __al_big_sub
    jmp .left
.right_minus:
    mov rdi, r12
    mov rsi, rbx
    call __al_big_sub
.right:
    mov rdi, rbx
    mov rsi, r12
    call __al_big_copy
    mov r13, r14
    shr r15d, 1
    jmp .left
.zero:
    mov qword [rbx], 0
    xor r13d, r13d
    xor r15d, r15d
.left:
    mov rax, r13
    mov edx, r15d
    and edx, 1
    add rsp, 64
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
