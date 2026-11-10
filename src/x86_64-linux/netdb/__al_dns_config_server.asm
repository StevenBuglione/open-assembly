; Add one distinct numeric resolver server to the primary/bank pair.
; RDI token, RSI primary sockaddr, RDX alternate bank, ECX primary length.
; Return the new primary length. Bank has 32 bytes of candidate scratch at +80.
bits 64
default rel

global __al_dns_config_server:function
extern inet_pton:function
extern memcmp:function
extern memcpy:function

section .text.__al_dns_config_server alloc exec nowrite progbits
__al_dns_config_server:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov r15d, ecx
    cmp dword [r14], 2
    jae .return
    lea rbx, [r14 + 80]
    xor eax, eax
    mov [rbx], rax
    mov [rbx + 8], rax
    mov [rbx + 16], rax
    mov [rbx + 24], rax
    mov edi, 2
    mov rsi, r12
    lea rdx, [rbx + 4]
    call inet_pton
    test eax, eax
    jnz .ipv4
    mov edi, 10
    mov rsi, r12
    lea rdx, [rbx + 8]
    call inet_pton
    test eax, eax
    jz .return
    mov word [rbx], 10
    mov dword [rsp], 28
    jmp .complete
.ipv4:
    mov word [rbx], 2
    mov dword [rsp], 16
.complete:
    mov word [rbx + 2], 0x3500
    test r15d, r15d
    jz .primary
    mov rdi, r13
    mov rsi, rbx
    mov edx, 32
    call memcmp
    test eax, eax
    jz .return
    xor r12d, r12d
.duplicate:
    cmp r12d, [r14]
    jae .alternate
    mov rax, r12
    shl rax, 5
    lea rdi, [r14 + rax + 16]
    mov rsi, rbx
    mov edx, 32
    call memcmp
    test eax, eax
    jz .return
    inc r12d
    jmp .duplicate
.alternate:
    mov eax, [rsp]
    mov [r14 + r12 * 4 + 4], eax
    shl r12, 5
    lea rdi, [r14 + r12 + 16]
    mov rsi, rbx
    mov edx, 32
    call memcpy
    inc dword [r14]
    jmp .return
.primary:
    mov rdi, r13
    mov rsi, rbx
    mov edx, 32
    call memcpy
    mov r15d, [rsp]
.return:
    mov eax, r15d
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
