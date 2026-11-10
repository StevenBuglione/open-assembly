; Original decimal field formatter. Inputs: cursor, reserved end, signed
; value, minimum magnitude digits, and a padding byte. Return cursor or null.
bits 64
default rel

global __al_strftime_number:function

section .text.__al_strftime_number alloc exec nowrite progbits
__al_strftime_number:
    push rbx
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
    lea rax, [rdi + rcx]
    add rax, r11
    cmp rax, rsi
    ja .failure
    mov rsi, rax
    mov r10, rax
    test r11d, r11d
    jz .unsigned
    mov byte [rdi], 45           ; sign precedes magnitude padding
.unsigned:
    mov rax, r9
.write_digit:
    xor edx, edx
    div rbx
    add dl, 48
    dec r10
    mov [r10], dl
    dec rcx
    test rax, rax
    jnz .write_digit
    test rcx, rcx
    jz .success
.pad:
    dec r10
    mov [r10], r8b
    dec rcx
    jnz .pad
.success:
    mov rax, rsi
    pop rbx
    ret
.failure:
    xor eax, eax
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
