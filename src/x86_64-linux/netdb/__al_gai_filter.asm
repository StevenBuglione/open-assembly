; Filter the resolver context's 24-byte address records in place.
; The requested family and flags are at offsets 12 and 16.
bits 64
default rel

global __al_gai_filter:function

section .text.__al_gai_filter alloc exec nowrite progbits
__al_gai_filter:
    mov r8d, [rdi + 12]
    test r8d, r8d              ; AF_UNSPEC retains all families
    jz .success
    mov ecx, [rdi]
    imul ecx, 24
    lea rdx, [rdi + 64]
    lea rcx, [rdx + rcx]        ; end of the original records
    mov rsi, rdx
    xor r9d, r9d                ; map IPv4 to IPv6 when policy allows
    cmp r8d, 10
    jne .compact_start
    test dword [rdi + 16], 8    ; AI_V4MAPPED
    jz .compact_start
    mov r9d, 1
    test dword [rdi + 16], 16   ; AI_ALL
    jnz .compact_start
    mov rax, rdx
.look_for_ipv6:
    cmp rax, rcx
    jae .compact_start
    cmp dword [rax], 10
    je .prefer_ipv6
    add rax, 24
    jmp .look_for_ipv6
.prefer_ipv6:
    xor r9d, r9d
.compact_start:
    xor r10d, r10d              ; number of retained addresses
.next:
    cmp rsi, rcx
    jae .finish
    mov eax, [rsi]
    cmp eax, r8d
    je .copy
    test r9d, r9d
    jz .advance
    cmp eax, 2
    jne .advance
    mov eax, [rsi + 8]          ; source and destination can be the same record
    mov dword [rdx], 10
    mov dword [rdx + 4], 0
    mov qword [rdx + 8], 0
    mov dword [rdx + 16], 0xffff0000
    mov [rdx + 20], eax
    jmp .retained
.copy:
    mov rax, [rsi]
    mov [rdx], rax
    mov rax, [rsi + 8]
    mov [rdx + 8], rax
    mov rax, [rsi + 16]
    mov [rdx + 16], rax
.retained:
    inc r10d
    add rdx, 24
.advance:
    add rsi, 24
    jmp .next
.finish:
    mov [rdi], r10d
    test r10d, r10d
    jz .not_found
.success:
    xor eax, eax
    ret
.not_found:
    mov eax, -2                 ; EAI_NONAME
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
