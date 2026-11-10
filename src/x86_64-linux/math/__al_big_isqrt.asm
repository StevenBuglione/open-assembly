; Compute the floor square root of bignum rsi into rdi, with remainder and trial scratch in rdx and rcx.
bits 64
default rel

global __al_big_isqrt:function
extern __al_big_bits:function
extern __al_big_muladd:function
extern __al_big_copy:function
extern __al_big_cmp:function
extern __al_big_sub:function

section .text.__al_big_isqrt alloc exec nowrite progbits
__al_big_isqrt:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov qword [rbx], 0
    mov qword [r13], 0
    mov rdi, r12
    call __al_big_bits
    test rax, rax
    jz .done
    dec rax
    shr rax, 1
    mov r15, rax
.pair:
    mov rax, r15
    shr rax, 4
    mov ecx, r15d
    and ecx, 15
    add ecx, ecx
    mov edx, [r12 + rax*4 + 8]
    shr edx, cl
    and edx, 3
    mov rdi, r13
    mov esi, 4
    call __al_big_muladd
    mov rdi, r14
    mov rsi, rbx
    call __al_big_copy
    mov rdi, r14
    mov esi, 4
    mov edx, 1
    call __al_big_muladd

    mov dword [rsp], 0
    mov rdi, r13
    mov rsi, r14
    call __al_big_cmp
    test eax, eax
    js .root_bit
    mov rdi, r13
    mov rsi, r14
    call __al_big_sub
    mov dword [rsp], 1
.root_bit:
    mov rdi, rbx
    mov esi, 2
    mov edx, [rsp]
    call __al_big_muladd
    test r15, r15
    jz .done
    dec r15
    jmp .pair
.done:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
