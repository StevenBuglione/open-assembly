; Floor of rsi/rdx at rcx bits into rdi. Numerator is scratch and below denominator.
bits 64
default rel

global __al_fixed_ratio_precision:function
extern __al_big_left:function
extern __al_big_cmp:function
extern __al_big_sub:function

section .text.__al_fixed_ratio_precision alloc exec nowrite progbits
__al_fixed_ratio_precision:
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
    shr r14, 5
    mov [rsp + 8], r14
.word:
    dec r14
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
    js .next
    mov rdi, r12
    mov rsi, r13
    call __al_big_sub
    or r15d, 1
.next:
    dec dword [rsp]
    jnz .bit
    mov [rbx + r14*4 + 8], r15d
    test r14, r14
    jnz .word
    mov rax, [rsp + 8]
.trim:
    test rax, rax
    jz .save
    cmp dword [rbx + rax*4 + 4], 0
    jne .save
    dec rax
    jmp .trim
.save:
    mov [rbx], rax
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
