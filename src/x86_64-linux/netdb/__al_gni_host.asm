; Render the host into the context's 256-byte buffer at offset 64.
; The context also provides a candidate address, token cursor and line buffer.
bits 64
default rel

global __al_gni_host:function
extern __al_gai_line:function
extern __al_gai_word:function
extern fclose:function
extern fopen:function
extern inet_ntop:function
extern inet_pton:function
extern snprintf:function
extern strlen:function

section .text.__al_gni_host alloc exec nowrite progbits
__al_gni_host:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi                ; context
    mov r12, rsi                ; sockaddr
    mov r13d, edx               ; flags
    movzx r15d, word [r12]
    test r13d, 1                ; NI_NUMERICHOST bypasses all local names
    jnz .numeric
    cmp r15d, 2
    jne .loopback_ipv6
    cmp dword [r12 + 4], 0x0100007f
    je .localhost
    jmp .open_file
.loopback_ipv6:
    cmp qword [r12 + 8], 0
    jne .open_file
    mov rax, 0x0100000000000000
    cmp [r12 + 16], rax
    je .localhost
.open_file:
    lea rdi, [rel hosts_path]
    lea rsi, [rel read_mode]
    call fopen
    test rax, rax
    jz .missing
    mov r14, rax
.read_line:
    mov rdi, r14
    lea rsi, [rbx + 1088]
    call __al_gai_line
    test rax, rax
    jz .close_missing
    mov [rbx + 40], rax
    lea rdi, [rbx + 40]
    call __al_gai_word
    test rax, rax
    jz .read_line
    mov edi, r15d
    mov rsi, rax
    lea rdx, [rbx + 48]
    call inet_pton
    test eax, eax
    jz .read_line
    cmp r15d, 2
    jne .compare_ipv6
    mov eax, [rbx + 48]
    cmp [r12 + 4], eax
    jne .read_line
    jmp .read_name
.compare_ipv6:
    mov rax, [rbx + 48]
    cmp [r12 + 8], rax
    jne .read_line
    mov rax, [rbx + 56]
    cmp [r12 + 16], rax
    jne .read_line
.read_name:
    lea rdi, [rbx + 40]
    call __al_gai_word
    test rax, rax
    jz .read_line
    mov rsi, rax
    xor ecx, ecx
.copy_name:
    cmp ecx, 256
    jae .read_line              ; a malformed overlong canonical name
    movzx eax, byte [rsi + rcx]
    test r13d, 4                ; NI_NOFQDN
    jz .store
    test ecx, ecx
    jz .store
    cmp eax, 46
    jne .store
    xor eax, eax
.store:
    mov [rbx + rcx + 64], al
    inc ecx
    test eax, eax
    jnz .copy_name
    mov rdi, r14
    call fclose
    jmp .success
.close_missing:
    mov rdi, r14
    call fclose
.missing:
    test r13d, 8                ; NI_NAMEREQD
    jnz .not_found
.numeric:
    mov edi, r15d
    lea rsi, [r12 + 4]
    cmp r15d, 2
    je .render
    lea rsi, [r12 + 8]
.render:
    lea rdx, [rbx + 64]
    mov ecx, 256
    call inet_ntop
    test rax, rax
    jz .failed
    cmp r15d, 10
    jne .success
    cmp dword [r12 + 24], 0
    je .success
    lea rdi, [rbx + 64]
    call strlen
    lea rdi, [rbx + rax + 64]
    mov esi, 256
    sub rsi, rax
    lea rdx, [rel scope_format]
    mov ecx, [r12 + 24]
    xor eax, eax
    call snprintf
    test eax, eax
    js .failed
    jmp .success
.localhost:
    mov rax, 0x736f686c61636f6c ; localhos
    mov [rbx + 64], rax
    mov word [rbx + 72], 116   ; t and the terminating null
.success:
    xor eax, eax
    jmp .return
.not_found:
    mov eax, -2                 ; EAI_NONAME
    jmp .return
.failed:
    mov eax, -4                 ; EAI_FAIL
.return:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata.__al_gni_host alloc noexec nowrite progbits
hosts_path: db "/etc/hosts", 0
read_mode: db "r", 0
scope_format: db "%%%u", 0

section .note.GNU-stack noalloc noexec nowrite progbits
