; Build one bounded lowercase IN question for A or AAAA.
bits 64
default rel

global __al_dns_build:function

section .text.__al_dns_build alloc exec nowrite progbits
__al_dns_build:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi                ; name
    mov r13, rcx                ; packet
    mov r14d, esi               ; host-order type
    movzx r15d, dx              ; transaction ID
    mov rbx, r8                ; packet capacity
    cmp r14d, 1
    je .measure
    cmp r14d, 28
    jne .invalid
.measure:
    mov r8d, 1                  ; terminal root label
    xor ecx, ecx                ; current label length
    cmp byte [rdi], 46
    jne .measure_byte
    cmp byte [rdi + 1], 0
    je .size_ready              ; the root name by itself
.measure_byte:
    movzx eax, byte [rdi]
    test eax, eax
    jz .last_label
    cmp eax, 46
    je .separator
    cmp eax, 45
    je .label_byte
    cmp eax, 95
    je .label_byte
    lea r9d, [rax - 48]
    cmp r9d, 9
    jbe .label_byte
    or eax, 32
    sub eax, 97
    cmp eax, 25
    ja .invalid
.label_byte:
    inc ecx
    cmp ecx, 63
    ja .invalid
    inc rdi
    jmp .measure_byte
.separator:
    test ecx, ecx
    jz .invalid
    lea r8d, [r8 + rcx + 1]
    cmp r8d, 255
    ja .invalid
    xor ecx, ecx
    inc rdi
    cmp byte [rdi], 0
    jne .measure_byte
    jmp .size_ready
.last_label:
    test ecx, ecx
    jz .invalid
    lea r8d, [r8 + rcx + 1]
    cmp r8d, 255
    ja .invalid
.size_ready:
    lea r9d, [r8 + 16]         ; DNS header, wire name and QTYPE/QCLASS
    cmp r9, rbx
    ja .invalid
    mov qword [r13], 0
    mov dword [r13 + 8], 0
    rol r15w, 8
    mov [r13], r15w
    mov word [r13 + 2], 1       ; network-order RD (0x0100)
    mov word [r13 + 4], 256     ; network-order QDCOUNT of one
    lea rdx, [r13 + 12]
    cmp r8d, 1
    je .root
    mov rsi, rdx                ; current label's length byte
    inc rdx
    xor ecx, ecx
.write_byte:
    movzx eax, byte [r12]
    test eax, eax
    jz .finish_label
    cmp eax, 46
    je .write_separator
    lea edi, [rax - 65]
    cmp edi, 25
    ja .store_byte
    add eax, 32
.store_byte:
    mov [rdx], al
    inc rdx
    inc ecx
    inc r12
    jmp .write_byte
.write_separator:
    mov [rsi], cl
    inc r12
    cmp byte [r12], 0
    je .root
    mov rsi, rdx
    inc rdx
    xor ecx, ecx
    jmp .write_byte
.finish_label:
    mov [rsi], cl
.root:
    mov byte [rdx], 0
    rol r14w, 8
    mov [rdx + 1], r14w
    mov word [rdx + 3], 256     ; QCLASS IN
    mov eax, r9d
    jmp .return
.invalid:
    xor eax, eax
.return:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
