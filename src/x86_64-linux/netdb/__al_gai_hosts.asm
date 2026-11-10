; Resolve numeric, synthetic or local-file node names.
; Context offsets: count 0, family 12, flags 16, canonical pointer 32,
; token cursor 40, 24-byte address records 64, canonical buffer 832,
; and line buffer 1088. Records contain family, scope and 16 address bytes.
bits 64
default rel

global __al_gai_hosts:function
extern __al_gai_equalname:function
extern __al_gai_line:function
extern __al_gai_word:function
extern __al_ipv6_zone_id:function
extern fclose:function
extern fopen:function
extern inet_pton:function
extern memcpy:function
extern strchr:function
extern strlen:function

section .text.__al_gai_hosts alloc exec nowrite progbits
__al_gai_hosts:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi                ; context
    mov r12, rsi                ; caller's node
    test rsi, rsi
    jz .null_node
    cmp byte [rsi], 0
    je .not_found
    mov rdi, r12
    mov esi, 37                 ; percent scope delimiter
    call strchr
    test rax, rax
    jnz .scoped_ipv6
    mov edi, 10                 ; AF_INET6
    mov rsi, r12
    lea rdx, [rbx + 72]
    call inet_pton
    test eax, eax
    jnz .numeric_ipv6
    mov edi, 2                  ; AF_INET
    mov rsi, r12
    lea rdx, [rbx + 72]
    call inet_pton
    test eax, eax
    jnz .numeric_ipv4
    test dword [rbx + 16], 4   ; AI_NUMERICHOST
    jnz .not_found
    mov rdi, r12
    lea rsi, [rel localhost]
    call __al_gai_equalname
    test eax, eax
    jz .host_file
    lea rax, [rel localhost]
    mov [rbx + 32], rax
    mov eax, 1
    jmp .both_families
.scoped_ipv6:
    mov r13, rax
    mov r15, rax
    sub r15, r12
    jz .not_found
    cmp r15, 45
    ja .not_found
    lea rdi, [rbx + 1088]
    mov rsi, r12
    mov rdx, r15
    call memcpy
    mov byte [rax + r15], 0
    mov edi, 10
    mov rsi, rax
    lea rdx, [rbx + 72]
    call inet_pton
    test eax, eax
    jz .not_found
    lea rdi, [r13 + 1]
    lea rsi, [rbx + 72]
    lea rdx, [rbx + 1136]      ; ifreq beyond the temporary address text
    call __al_ipv6_zone_id
    test rax, rax
    js .return
    mov [rbx + 68], eax
.numeric_ipv6:
    mov dword [rbx + 64], 10
    jmp .numeric_done
.numeric_ipv4:
    mov dword [rbx + 64], 2
.numeric_done:
    mov [rbx + 32], r12
    mov dword [rbx], 1
    jmp .success
.null_node:
    xor eax, eax                ; wildcard addresses for AI_PASSIVE
    test dword [rbx + 16], 1
    jnz .synthetic_family
    mov eax, 1                  ; otherwise use loopback addresses
.synthetic_family:
    cmp dword [rbx + 12], 2
    je .only_ipv4
    cmp dword [rbx + 12], 10
    jne .both_families
    mov edx, [rbx + 16]
    and edx, 40                 ; AI_ADDRCONFIG | AI_V4MAPPED
    cmp edx, 40
    jne .only_ipv6
.both_families:
    mov dword [rbx + 64], 10
    mov [rbx + 87], al          ; last IPv6 address byte
    mov dword [rbx + 88], 2
    test eax, eax
    jz .both_done
    mov dword [rbx + 96], 0x0100007f
.both_done:
    mov dword [rbx], 2
    jmp .success
.only_ipv4:
    mov dword [rbx + 64], 2
    test eax, eax
    jz .one_done
    mov dword [rbx + 72], 0x0100007f
    jmp .one_done
.only_ipv6:
    mov dword [rbx + 64], 10
    mov [rbx + 87], al
.one_done:
    mov dword [rbx], 1
    jmp .success
.host_file:
    lea rdi, [rel hosts_path]
    lea rsi, [rel read_mode]
    call fopen
    test rax, rax
    jz .not_found
    mov r13, rax
.read_line:
    mov rdi, r13
    lea rsi, [rbx + 1088]
    call __al_gai_line
    test rax, rax
    jz .close_file
    mov [rbx + 40], rax
    lea rdi, [rbx + 40]
    call __al_gai_word
    test rax, rax
    jz .read_line
    mov [rsp], rax              ; address token
    lea rdi, [rbx + 40]
    call __al_gai_word
    test rax, rax
    jz .read_line
    mov r14, rax                ; primary name for this row
.check_alias:
    mov rdi, r12
    mov rsi, rax
    call __al_gai_equalname
    test eax, eax
    jnz .matched
    lea rdi, [rbx + 40]
    call __al_gai_word
    test rax, rax
    jnz .check_alias
    jmp .read_line
.matched:
    mov eax, [rbx]
    imul eax, 24
    lea r15, [rbx + rax + 64]
    mov edi, 10
    mov rsi, [rsp]
    lea rdx, [r15 + 8]
    call inet_pton
    test eax, eax
    jnz .save_ipv6
    mov edi, 2
    mov rsi, [rsp]
    lea rdx, [r15 + 8]
    call inet_pton
    test eax, eax
    jz .read_line
    mov dword [r15], 2
    jmp .save_address
.save_ipv6:
    mov dword [r15], 10
.save_address:
    inc dword [rbx]
    cmp qword [rbx + 32], 0
    jne .check_capacity
    mov rdi, r14
    call strlen
    cmp rax, 255
    ja .fallback_name
    lea rdx, [rbx + 832]
    mov [rbx + 32], rdx
    xor ecx, ecx
.copy_name:
    mov al, [r14 + rcx]
    mov [rdx + rcx], al
    inc rcx
    test al, al
    jnz .copy_name
    jmp .check_capacity
.fallback_name:
    mov [rbx + 32], r12
.check_capacity:
    cmp dword [rbx], 32
    jb .read_line
.close_file:
    mov rdi, r13
    call fclose
    cmp dword [rbx], 0
    je .not_found
.success:
    xor eax, eax
    jmp .return
.not_found:
    mov eax, -2                 ; EAI_NONAME
.return:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata.__al_gai_hosts alloc noexec nowrite progbits
hosts_path: db "/etc/hosts", 0
read_mode: db "r", 0
localhost: db "localhost", 0

section .note.GNU-stack noalloc noexec nowrite progbits
