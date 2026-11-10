; Original RFC 9636 parser. Inputs: writable file bytes, length, zone record.
; Return zero on success. The caller publishes the record only after validation.
bits 64
default rel

global __al_tzif_parse:function

section .text.__al_tzif_parse alloc exec nowrite progbits
__al_tzif_parse:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 48
    mov rbx, rdi
    mov r12, rdi
    add r12, rsi
    jc .invalid
    mov r13, rdx
    mov r14d, 4
    xor r15d, r15d
.header:
    mov rdx, r12
    sub rdx, rbx
    cmp rdx, 44
    jb .invalid
    cmp dword [rbx], 0x66695a54  ; TZif
    jne .invalid
    cmp qword [rbx + 5], 0
    jne .invalid
    cmp qword [rbx + 12], 0
    jne .invalid
    movzx eax, byte [rbx + 4]
    cmp r14d, 8
    je .second_version
    test eax, eax
    jz .counts
    cmp eax, 50
    jb .invalid
    cmp eax, 52
    ja .invalid
    mov r15d, eax
    jmp .counts
.second_version:
    cmp eax, r15d
    jne .invalid
.counts:
    mov eax, [rbx + 20]           ; UT/local indicators
    bswap eax
    mov [rsp], rax
    mov eax, [rbx + 24]           ; standard/wall indicators
    bswap eax
    mov [rsp + 8], rax
    mov eax, [rbx + 28]           ; leap records
    bswap eax
    mov [rsp + 16], rax
    mov eax, [rbx + 32]           ; transition times and type indices
    bswap eax
    mov [rsp + 24], rax
    mov eax, [rbx + 36]           ; local time types
    bswap eax
    test eax, eax
    jz .invalid
    cmp eax, 256
    ja .invalid
    mov [rsp + 32], rax
    cmp qword [rsp], 0
    je .standard_count
    cmp [rsp], rax
    jne .invalid
.standard_count:
    cmp qword [rsp + 8], 0
    je .characters
    cmp [rsp + 8], rax
    jne .invalid
.characters:
    mov eax, [rbx + 40]           ; designation bytes
    bswap eax
    test eax, eax
    jz .invalid
    mov [rsp + 40], rax

    ; The six unsigned 32-bit counts keep this arithmetic below 2^38.
    lea rax, [r14 + 1]
    imul rax, [rsp + 24]
    lea rcx, [r14 + 4]
    imul rcx, [rsp + 16]
    add rax, rcx
    mov rcx, [rsp + 32]
    imul rcx, 6
    add rax, rcx
    add rax, [rsp + 40]
    add rax, [rsp + 8]
    add rax, [rsp]
    add rax, 44
    cmp rax, rdx
    ja .invalid
    lea r10, [rbx + rax]          ; complete data block end
    cmp r14d, 8
    je .layout
    test r15d, r15d
    jz .layout
    mov rbx, r10                 ; skip compatibility block
    mov r14d, 8
    jmp .header

.layout:
    lea rax, [rbx + 44]
    mov [r13 + 16], rax          ; transition times
    mov rcx, [rsp + 24]
    mov [r13 + 56], rcx
    imul rcx, r14
    add rax, rcx
    mov [r13 + 24], rax          ; transition type indices
    add rax, [rsp + 24]
    mov [r13 + 32], rax          ; six-byte local time type records
    mov rcx, [rsp + 32]
    mov [r13 + 64], rcx
    imul rcx, 6
    add rax, rcx
    mov [r13 + 40], rax          ; designation strings
    add rax, [rsp + 40]
    cmp byte [rax - 1], 0
    jne .invalid
    mov [r13 + 80], rax          ; leap records, for epoch translation
    mov rcx, [rsp + 16]
    mov [r13 + 88], rcx
    lea rdx, [r14 + 4]
    imul rcx, rdx
    add rax, rcx
    mov [r13 + 72], r14
    mov [r13 + 96], r15          ; source format version

    ; If the optional indicator arrays are present, check the paired values.
    mov rcx, [rsp + 8]
    lea r11, [rax + rcx]          ; start of UT/local indicators
    xor edx, edx
.standard_flags:
    cmp rdx, rcx
    jae .ut_flags
    cmp byte [rax + rdx], 1
    ja .invalid
    inc rdx
    jmp .standard_flags
.ut_flags:
    xor edx, edx
.ut_flag:
    cmp rdx, [rsp]
    jae .type_records
    movzx esi, byte [r11 + rdx]
    cmp esi, 1
    ja .invalid
    test esi, esi
    jz .next_flag
    test rcx, rcx
    jz .invalid
    cmp byte [rax + rdx], 1
    jne .invalid
.next_flag:
    inc rdx
    jmp .ut_flag

.type_records:
    mov rax, [r13 + 32]
    mov rcx, [rsp + 32]
.type:
    mov edx, [rax]
    bswap edx
    cmp edx, -2147483648
    je .invalid
    cmp byte [rax + 4], 1
    ja .invalid
    movzx edx, byte [rax + 5]
    cmp rdx, [rsp + 40]
    jae .invalid
    add rax, 6
    dec rcx
    jnz .type

    mov rax, [r13 + 24]
    mov rdi, [r13 + 16]
    xor r8d, r8d
.transition:
    cmp r8, [rsp + 24]
    jae .footer
    movzx edx, byte [rax + r8]
    cmp rdx, [rsp + 32]
    jae .invalid
    cmp r14d, 8
    je .time64
    mov edx, [rdi]
    bswap edx
    movsxd rdx, edx
    jmp .time_order
.time64:
    mov rdx, [rdi]
    bswap rdx
.time_order:
    test r8, r8
    jz .next_transition
    cmp rdx, r9
    jle .invalid
.next_transition:
    mov r9, rdx
    add rdi, r14
    inc r8
    jmp .transition

.footer:
    mov qword [r13 + 48], 0
    cmp r14d, 8
    je .footer64
    cmp r10, r12
    jne .invalid
    jmp .success
.footer64:
    lea rax, [r10 + 2]
    cmp rax, r12
    ja .invalid
    cmp byte [r10], 10
    jne .invalid
    lea rdx, [r12 - 1]
    cmp byte [rdx], 10
    jne .invalid
    lea rax, [r10 + 1]
    cmp rax, rdx
    je .success
    mov [r13 + 48], rax
.footer_byte:
    cmp rax, rdx
    je .terminate_footer
    movzx ecx, byte [rax]
    sub ecx, 32
    cmp ecx, 94
    ja .invalid
    inc rax
    jmp .footer_byte
.terminate_footer:
    mov byte [rdx], 0
.success:
    xor eax, eax
    jmp .done
.invalid:
    mov eax, -1
.done:
    add rsp, 48
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
