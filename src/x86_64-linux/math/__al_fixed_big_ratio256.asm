; Q256 floor of positive numerator rsi below denominator rdx into rdi. Mutates numerator.
bits 64
default rel

global __al_fixed_big_ratio256:function
extern __al_big_left:function
extern __al_big_cmp:function
extern __al_big_sub:function

section .text.__al_fixed_big_ratio256 alloc exec nowrite progbits
__al_fixed_big_ratio256:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14d, 8
.word:
    dec r14d
    xor r15d, r15d
    mov dword [rsp], 32
.bit:
    shl r15d, 1
    mov rdi, r12
    mov esi, 1
    call __al_big_left
    mov rdi, r12
    mov rsi, r13
    call __al_big_cmp
    test eax, eax
    js .next_bit
    mov rdi, r12
    mov rsi, r13
    call __al_big_sub
    or r15d, 1
.next_bit:
    dec dword [rsp]
    jnz .bit
    mov [rbx + r14*4 + 8], r15d
    test r14d, r14d
    jnz .word
    mov eax, 8
.normalize:
    test eax, eax
    jz .count
    cmp dword [rbx + rax*4 + 4], 0
    jne .count
    dec eax
    jmp .normalize
.count:
    mov [rbx], rax
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
