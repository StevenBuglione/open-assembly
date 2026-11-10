; Add nonoverlapping bignum at rsi to bignum at rdi, with checked capacity.
bits 64
default rel

global __al_big_add:function
extern __al_big_bad:function

section .text.__al_big_add alloc exec nowrite progbits
__al_big_add:
    mov r10, [rdi]
    mov r11, [rsi]
    xor r8d, r8d
    xor r9d, r9d
.next:
    xor eax, eax
    cmp r8, r10
    jae .right
    mov eax, [rdi + r8*4 + 8]
.right:
    xor edx, edx
    cmp r8, r11
    jae .remaining
    mov edx, [rsi + r8*4 + 8]
    jmp .sum
.remaining:
    cmp r8, r10
    jae .carry
.sum:
    add rax, rdx
    add rax, r9
    mov [rdi + r8*4 + 8], eax
    shr rax, 32
    mov r9, rax
    inc r8
    jmp .next
.carry:
    test r9d, r9d
    jz .size
    cmp r8, 2560
    jae .capacity
    mov [rdi + r8*4 + 8], r9d
    inc r8
.size:
    mov [rdi], r8
    ret
.capacity:
    sub rsp, 8
    call __al_big_bad

section .note.GNU-stack noalloc noexec nowrite progbits
