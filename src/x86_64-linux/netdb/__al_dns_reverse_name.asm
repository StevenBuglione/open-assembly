; Render an IN PTR query name. RDI output (at least 73 bytes), RSI address
; bytes, EDX lookup family, RCX four writable scratch bytes for IPv4.
bits 64
default rel

global __al_dns_reverse_name:function
extern __al_inet_text4:function

section .text.__al_dns_reverse_name alloc exec nowrite progbits
__al_dns_reverse_name:
    cmp edx, 2
    je .ipv4
    lea r8, [rel digits]
    mov ecx, 15
.ipv6_byte:
    movzx eax, byte [rsi + rcx]
    mov edx, eax
    and eax, 15
    shr edx, 4
    mov al, [r8 + rax]
    mov [rdi], al
    mov byte [rdi + 1], 46
    mov al, [r8 + rdx]
    mov [rdi + 2], al
    mov byte [rdi + 3], 46
    add rdi, 4
    dec ecx
    jns .ipv6_byte
    mov rax, [rel ipv6_suffix]
    mov [rdi], rax
    mov byte [rdi + 8], 0
    ret
.ipv4:
    push rbx
    mov rbx, rdi
    mov eax, [rsi]
    bswap eax
    mov [rcx], eax
    mov rdi, rcx
    mov rsi, rbx
    call __al_inet_text4
    lea rcx, [rel ipv4_suffix]
    mov rdx, [rcx]
    mov [rbx + rax], rdx
    mov edx, [rcx + 8]
    mov [rbx + rax + 8], edx
    mov dx, [rcx + 12]
    mov [rbx + rax + 12], dx
    pop rbx
    ret

section .rodata.__al_dns_reverse_name alloc noexec nowrite progbits
digits: db "0123456789abcdef"
ipv4_suffix: db ".in-addr.arpa", 0
ipv6_suffix: db "ip6.arpa"

section .note.GNU-stack noalloc noexec nowrite progbits
