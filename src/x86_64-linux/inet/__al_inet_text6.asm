; Measure canonical IPv6 text, or write to a nonnull destination.
; Return the character count without a terminating null.
bits 64
default rel

global __al_inet_text6:function
extern __al_inet_text4:function

section .text.__al_inet_text6 alloc exec nowrite progbits
__al_inet_text6:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    mov r13, rsi
    cmp qword [r12], 0
    jne .find_gap
    cmp dword [r12 + 8], 0xffff0000
    jne .find_gap
    test r13, r13
    jz .mapped_suffix
    mov dword [r13], 0x66663a3a ; ::ff
    mov word [r13 + 4], 0x6666  ; ff
    mov byte [r13 + 6], 58
    lea rsi, [r13 + 7]
.mapped_suffix:
    lea rdi, [r12 + 12]
    call __al_inet_text4
    add eax, 7
    jmp .return
.find_gap:
    xor ecx, ecx                ; word index
    xor r8d, r8d                ; current zero run length
    xor r15d, r15d              ; longest zero run length
    mov r14d, -1                ; longest zero run start
.scan_word:
    cmp word [r12 + rcx * 2], 0
    jne .reset_run
    inc r8d
    cmp r8d, r15d
    jbe .scan_next
    mov r15d, r8d
    lea r14d, [rcx + 1]
    sub r14d, r8d
    jmp .scan_next
.reset_run:
    xor r8d, r8d
.scan_next:
    inc ecx
    cmp ecx, 8
    jb .scan_word
    cmp r15d, 2
    jae .render
    xor r15d, r15d
    mov r14d, -1                ; a single zero remains a normal word
.render:
    lea r9d, [r14 + r15]        ; first word after the compressed run
    xor r8d, r8d                ; word index
    xor ebx, ebx                ; emitted bytes
.word:
    cmp r8d, r14d
    je .gap
    test r8d, r8d
    jz .load_word
    cmp r8d, r9d
    je .load_word
    test r13, r13
    jz .separator_done
    mov byte [r13 + rbx], 58
.separator_done:
    inc ebx
.load_word:
    movzx edx, word [r12 + r8 * 2]
    rol dx, 8
    mov ecx, 12
.first_digit:
    mov eax, edx
    shr eax, cl
    and eax, 15
    test eax, eax
    jnz .write_digit
    test ecx, ecx
    jz .write_digit
    sub ecx, 4
    jmp .first_digit
.next_digit:
    mov eax, edx
    shr eax, cl
    and eax, 15
.write_digit:
    test r13, r13
    jz .digit_done
    cmp eax, 9
    jbe .decimal_digit
    add eax, 87
    jmp .store_digit
.decimal_digit:
    add eax, 48
.store_digit:
    mov [r13 + rbx], al
.digit_done:
    inc ebx
    test ecx, ecx
    jz .word_done
    sub ecx, 4
    jmp .next_digit
.word_done:
    inc r8d
    jmp .next_word
.gap:
    test r13, r13
    jz .gap_done
    mov word [r13 + rbx], 0x3a3a
.gap_done:
    add ebx, 2
    add r8d, r15d
.next_word:
    cmp r8d, 8
    jb .word
    mov eax, ebx
.return:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
