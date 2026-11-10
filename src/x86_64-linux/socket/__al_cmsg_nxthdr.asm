; Return the next complete ancillary header within a native LP64 message.
bits 64
default rel

global __al_cmsg_nxthdr:function

section .text.__al_cmsg_nxthdr alloc exec nowrite progbits
__al_cmsg_nxthdr:
    test rsi, rsi
    jz .missing
    mov rcx, [rdi + 32]          ; msg_control
    test rcx, rcx
    jz .missing
    cmp rsi, rcx
    jb .missing
    mov rdx, rsi
    sub rdx, rcx
    mov rcx, [rdi + 40]          ; msg_controllen
    sub rcx, rdx
    jc .missing
    cmp rcx, 16
    jb .missing
    mov rax, [rsi]               ; cmsg_len
    cmp rax, 16
    jb .missing
    add rax, 7
    jc .missing
    and rax, -8
    sub rcx, rax
    jc .missing
    cmp rcx, 16
    jb .missing
    add rax, rsi
    jc .missing
    ret
.missing:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
