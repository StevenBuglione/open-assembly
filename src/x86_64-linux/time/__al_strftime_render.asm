; Original bounded format renderer. Inputs: cursor, reserved end, format, tm,
; and mode. Bit 0 selects wide output and bit 1 selects a wide format.
; Return the next cursor or null. Compound formats use the same renderer.
bits 64
default rel

global __al_strftime_render:function
extern __al_strftime_field:function

section .text.__al_strftime_render alloc exec nowrite progbits
__al_strftime_render:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov r15d, r8d
.next:
    test r15d, 2
    jnz .wide_next
    movzx edx, byte [r13]
    inc r13
    jmp .next_ready
.wide_next:
    mov edx, [r13]
    add r13, 4
.next_ready:
    test edx, edx
    jz .success
    cmp edx, 37                   ; %
    je .conversion
    cmp rbx, r12
    jae .failure
    test r15d, 1
    jnz .wide_literal
    mov [rbx], dl
    inc rbx
    jmp .next
.wide_literal:
    mov [rbx], edx
    add rbx, 4
    jmp .next
.conversion:
    test r15d, 2
    jnz .wide_conversion
    movzx edx, byte [r13]
    inc r13
    jmp .conversion_ready
.wide_conversion:
    mov edx, [r13]
    add r13, 4
.conversion_ready:
    cmp edx, 69                   ; E
    je .era_modifier
    cmp edx, 79                   ; O
    jne .field
    lea rax, [rel numeric_conversions]
    jmp .modifier
.era_modifier:
    lea rax, [rel era_conversions]
.modifier:
    test r15d, 2
    jnz .wide_modifier
    movzx edx, byte [r13]
    inc r13
    jmp .modifier_ready
.wide_modifier:
    mov edx, [r13]
    add r13, 4
.modifier_ready:
.valid_modifier:
    movzx ecx, byte [rax]
    test ecx, ecx
    jz .failure
    cmp ecx, edx
    je .field
    inc rax
    jmp .valid_modifier
.field:
    cmp edx, 127
    ja .failure
    mov rdi, rbx
    mov rsi, r12
    mov rcx, r14
    mov r8d, r15d
    and r8d, 1
    call __al_strftime_field
    test rax, rax
    jz .restore
    mov rbx, rax
    jmp .next
.success:
    mov rax, rbx
    jmp .restore
.failure:
    xor eax, eax
.restore:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.__al_strftime_render alloc noexec nowrite progbits
era_conversions: db "cCxXyY", 0
numeric_conversions: db "deHImMSuUVwWy", 0

section .note.GNU-stack noalloc noexec nowrite progbits
