; Try an absolute DNS name and bounded search suffixes in configured order.
bits 64
default rel

global __al_dns_lookup:function
extern __al_dns_build:function
extern __al_dns_config:function
extern __al_dns_lookup_one:function
extern calloc:function
extern free:function
extern memcpy:function
extern strlen:function

section .text.__al_dns_lookup alloc exec nowrite progbits
__al_dns_lookup:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32
    mov rbx, rdi                ; resolver context
    mov r13, rsi                ; original node
    mov edi, 1
    mov esi, 3136               ; answer, sockaddr, search record and candidate
    call calloc
    test rax, rax
    jz .no_memory
    mov r14, rax
    mov rdi, r13
    mov esi, 1
    xor edx, edx
    xor ecx, ecx
    mov r8d, 272
    call __al_dns_build
    test rax, rax
    jz .missing
    mov rdi, r13
    call strlen
    mov r12, rax
    mov rdi, rbx
    lea rsi, [r14 + 1032]
    lea rdx, [r14 + 1064]
    call __al_dns_config
    mov r15d, eax

    mov qword [rsp], 0          ; next search suffix
    mov dword [rsp + 8], 0     ; absolute not yet tried
    cmp byte [r13 + r12 - 1], 46
    je .absolute_only
    cmp dword [r14 + 1064], 0
    je .absolute_only
    xor ecx, ecx
    xor edx, edx
.count_dots:
    cmp byte [r13 + rdx], 46
    jne .next_byte
    inc ecx
.next_byte:
    inc rdx
    cmp rdx, r12
    jb .count_dots
    cmp ecx, [r14 + 1068]
    jb .next_suffix

.absolute:
    mov dword [rsp + 8], 1
    jmp .query_absolute
.absolute_only:
    mov dword [rsp + 8], 2
.query_absolute:
    mov rdi, rbx
    mov rsi, r13
    mov rdx, r14
    mov ecx, r15d
    mov r8, r13
    call __al_dns_lookup_one
    cmp eax, -2
    jne .release
    cmp dword [rsp + 8], 2
    je .release

.next_suffix:
    mov rax, [rsp]
    cmp eax, [r14 + 1064]
    jae .suffixes_done
    shl rax, 8
    lea rdi, [r14 + rax + 1072]
    mov [rsp + 16], rdi
    inc qword [rsp]
    call strlen
    lea rcx, [rax + r12 + 1]
    cmp rcx, 253               ; without the trailing root dot
    ja .next_suffix
    mov [rsp + 24], rax
    lea rdi, [r14 + 2880]
    mov rsi, r13
    mov rdx, r12
    call memcpy
    mov byte [rax + r12], 46
    lea rdi, [rax + r12 + 1]
    mov rsi, [rsp + 16]
    mov rdx, [rsp + 24]
    inc rdx                    ; include the suffix terminator
    call memcpy
    mov rdi, rbx
    lea rsi, [r14 + 2880]
    mov rdx, r14
    mov ecx, r15d
    mov r8, r13
    call __al_dns_lookup_one
    cmp eax, -2
    je .next_suffix
    jmp .release

.suffixes_done:
    cmp dword [rsp + 8], 0
    je .absolute
.missing:
    mov eax, -2                ; EAI_NONAME
.release:
    mov r12d, eax
    mov rdi, r14
    call free
    mov eax, r12d
    jmp .return
.no_memory:
    mov eax, -10               ; EAI_MEMORY
.return:
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
