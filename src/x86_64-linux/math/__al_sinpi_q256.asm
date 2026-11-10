; Compute sin(pi*f) in Q256 at rdi for 0 < f <= 1/2 at rsi. rdx holds three bignums and product scratch.
bits 64
default rel

global __al_sinpi_q256:function
extern __al_pi_q256:function
extern __al_fixed_mul256:function
extern __al_big_copy:function
extern __al_big_divsmall:function
extern __al_big_sub:function
extern __al_big_add:function

section .text.__al_sinpi_q256 alloc exec nowrite progbits
__al_sinpi_q256:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    lea r14, [rdx + 10248]
    lea r15, [rdx + 20496]
    mov rdi, r13
    mov esi, 4
    call __al_pi_q256
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    lea rcx, [r13 + 30744]
    call __al_fixed_mul256
    mov rdi, r14
    mov rsi, rbx
    call __al_big_copy
    mov rdi, r15
    mov rsi, rbx
    mov rdx, rbx
    lea rcx, [r13 + 30744]
    call __al_fixed_mul256
    mov dword [rsp + 8], 2
    mov dword [rsp + 4], 1
.term:
    mov rdi, r14
    mov rsi, r14
    mov rdx, r15
    lea rcx, [r13 + 30744]
    call __al_fixed_mul256
    mov esi, [rsp + 8]
    lea eax, [rsi + 1]
    imul esi, eax
    mov rdi, r14
    call __al_big_divsmall
    cmp qword [r14], 0
    je .done
    mov rdi, rbx
    mov rsi, r14
    cmp dword [rsp + 4], 0
    je .positive
    call __al_big_sub
    jmp .next
.positive:
    call __al_big_add
.next:
    xor dword [rsp + 4], 1
    add dword [rsp + 8], 2
    cmp dword [rsp + 8], 112
    jbe .term
.done:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
