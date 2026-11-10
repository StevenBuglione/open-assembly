; Original decimal field formatter. Inputs: cursor, reserved end, signed
; value, minimum magnitude digits, padding byte, and output stride.
; Return cursor or null.
bits 64
default rel

global __al_strftime_number:function

section .text.__al_strftime_number alloc exec nowrite progbits
__al_strftime_number:
    push rbx
    push r12
    mov r12d, r9d
    mov r9, rdx
    xor r11d, r11d
    test r9, r9
    jns .magnitude
    neg r9
    mov r11d, 1
.magnitude:
    mov rax, r9
    xor r10d, r10d
    mov ebx, 10
.measure:
    xor edx, edx
    div rbx
    inc r10
    test rax, rax
    jnz .measure
    cmp rcx, r10
    jae .width
    mov rcx, r10
.width:
    lea rax, [rcx + r11]
    imul rax, r12
    add rax, rdi
    jc .failure
    cmp rax, rsi
    ja .failure
    mov rsi, rax
    mov r10, rax
    test r11d, r11d
    jz .unsigned
    cmp r12d, 4
    je .wide_sign
    mov byte [rdi], 45          ; sign precedes magnitude padding
    jmp .unsigned
.wide_sign:
    mov dword [rdi], 45
.unsigned:
    mov rax, r9
.write_digit:
    xor edx, edx
    div rbx
    add edx, 48
    sub r10, r12
    cmp r12d, 4
    je .wide_digit
    mov [r10], dl
    jmp .next_digit
.wide_digit:
    mov [r10], edx
.next_digit:
    dec rcx
    test rax, rax
    jnz .write_digit
    test rcx, rcx
    jz .success
.pad:
    sub r10, r12
    cmp r12d, 4
    je .wide_pad
    mov [r10], r8b
    jmp .next_pad
.wide_pad:
    mov [r10], r8d
.next_pad:
    dec rcx
    jnz .pad
.success:
    mov rax, rsi
    pop r12
    pop rbx
    ret
.failure:
    xor eax, eax
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
