; Round a signed multiple of pi/4 (edi kind, esi multiple, edx sign).
bits 64
default rel

global __al_complex_constant_angle:function
extern __al_math_atan:function
extern __al_math_effects:function
extern __al_fp_pack_exact:function

section .text.__al_complex_constant_angle alloc exec nowrite progbits
__al_complex_constant_angle:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov ecx, edx
    test esi, esi
    jz .zero
    mov eax, esi
    lea rsi, [rel one]
    lea rdx, [rel one]
    cmp eax, 1
    je .angle
    cmp eax, 2
    jne .negative_horizontal
    lea rdx, [rel zero]
    jmp .angle
.negative_horizontal:
    or ecx, 2
    cmp eax, 4
    jne .angle
    lea rsi, [rel zero]
.angle:
    xor r8d, r8d
    mov r9d, 2
    call __al_math_atan
    mov rbx, rax
    mov r12d, edx
    mov edi, ecx
    xor esi, esi
    call __al_math_effects
    mov rax, rbx
    mov edx, r12d
    jmp .done
.zero:
    xor edx, edx
    call __al_fp_pack_exact
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata alloc noexec nowrite progbits
align 8
zero: dq 0
one: dq 1
     dd 1

section .note.GNU-stack noalloc noexec nowrite progbits
