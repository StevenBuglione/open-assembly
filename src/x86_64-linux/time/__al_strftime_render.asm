; Original bounded format renderer. Inputs: cursor, reserved end, format, tm.
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
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
.next:
    movzx edx, byte [r13]
    inc r13
    test dl, dl
    jz .success
    cmp dl, 37                   ; %
    je .conversion
    cmp rbx, r12
    jae .failure
    mov [rbx], dl
    inc rbx
    jmp .next
.conversion:
    movzx edx, byte [r13]
    inc r13
    cmp dl, 69                   ; E
    je .era_modifier
    cmp dl, 79                   ; O
    jne .field
    lea rax, [rel numeric_conversions]
    jmp .modifier
.era_modifier:
    lea rax, [rel era_conversions]
.modifier:
    movzx edx, byte [r13]
    inc r13
.valid_modifier:
    mov cl, [rax]
    test cl, cl
    jz .failure
    cmp cl, dl
    je .field
    inc rax
    jmp .valid_modifier
.field:
    mov rdi, rbx
    mov rsi, r12
    mov rcx, r14
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
