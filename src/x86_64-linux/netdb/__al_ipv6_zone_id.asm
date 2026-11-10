; Convert a decimal or interface-name IPv6 scope suffix to a 32-bit ID.
; RDI suffix, RSI IPv6 bytes, RDX writable ifreq scratch.
; RAX is the zero-extended scope ID or a negative EAI status.
bits 64
default rel

global __al_ipv6_zone_id:function
extern __al_ipv6_zone_kind:function
extern __al_ipv6_zone_name:function
extern __al_netdb_ifreq:function
extern memcpy:function

section .text.__al_ipv6_zone_id alloc exec nowrite progbits
__al_ipv6_zone_id:
    cmp byte [rdi], 0
    je .invalid
    xor ecx, ecx
.classify:
    movzx eax, byte [rdi + rcx]
    test eax, eax
    jz .decimal
    sub eax, 48
    cmp eax, 9
    ja .name
    inc rcx
    jmp .classify
.decimal:
    xor r8d, r8d
    xor eax, eax
    mov r9d, 0xffffffff
.accumulate:
    movzx edx, byte [rdi + r8]
    sub edx, 48
    imul rax, 10
    add rax, rdx
    cmp rax, r9
    ja .invalid
    inc r8
    cmp r8, rcx
    jb .accumulate
    ret

.name:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r13, rdx
    mov rdi, rsi
    call __al_ipv6_zone_kind
    test eax, 1
    jz .invalid_name
    mov rdi, rbx
    call __al_ipv6_zone_name
    test rax, rax
    jz .invalid_name
    mov r12, rax
    xor eax, eax
    mov [r13], rax
    mov [r13 + 8], rax
    mov [r13 + 16], rax
    mov [r13 + 24], rax
    mov [r13 + 32], rax
    mov rdi, r13
    mov rsi, rbx
    mov rdx, r12
    call memcpy
    mov rdi, r13
    mov esi, 0x8933            ; SIOCGIFINDEX
    call __al_netdb_ifreq
    test eax, eax
    jns .index
    cmp eax, -19               ; ENODEV
    je .invalid_name
    cmp eax, -6                ; ENXIO
    je .invalid_name
    mov rax, -3                ; EAI_AGAIN
    jmp .restore
.index:
    mov eax, [r13 + 16]
    test eax, eax
    jg .restore
.invalid_name:
    mov rax, -2                ; EAI_NONAME
.restore:
    pop r13
    pop r12
    pop rbx
    ret
.invalid:
    mov rax, -2
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
