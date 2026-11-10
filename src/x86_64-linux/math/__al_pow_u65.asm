; Compute a square or cube of the unsigned 65-bit rdx:rsi into four little-endian qwords at rdi.
bits 64
default rel

global __al_pow_u65:function

section .text.__al_pow_u65 alloc exec nowrite progbits
__al_pow_u65:
    push rbx
    push r12
    mov ebx, ecx
    mov r12, rdx
    mov rax, rsi
    mul rsi
    mov r8, rax
    mov r9, rdx
    xor r10d, r10d
    test r12, r12
    jz .square_ready
    mov r11, rsi
    add r11, r11
    adc r10, 1
    add r9, r11
    adc r10, 0
.square_ready:
    cmp ebx, 2
    jne .cube
    mov [rdi], r8
    mov [rdi + 8], r9
    mov [rdi + 16], r10
    mov qword [rdi + 24], 0
    jmp .done
.cube:
    mov rax, r8
    mul rsi
    mov [rdi], rax
    mov r11, rdx
    mov rax, r9
    mul rsi
    add rax, r11
    adc rdx, 0
    mov [rdi + 8], rax
    mov r11, rdx
    mov rax, r10
    mul rsi
    add rax, r11
    adc rdx, 0
    mov [rdi + 16], rax
    mov [rdi + 24], rdx
    test r12, r12
    jz .done
    add [rdi + 8], r8
    adc [rdi + 16], r9
    adc [rdi + 24], r10
.done:
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
