; Return the byte count through the first complete CRLF CRLF, or zero.
bits 64
default rel

global __al_http_find:function

section .text.__al_http_find alloc exec nowrite progbits
__al_http_find:
    cmp rsi, 4
    jb .missing
    sub rsi, 3                  ; possible four-byte starts
    xor ecx, ecx
.next:
    cmp dword [rdi + rcx], 0x0a0d0a0d
    je .found
    inc rcx
    cmp rcx, rsi
    jb .next
.missing:
    xor eax, eax
    ret
.found:
    lea rax, [rcx + 4]
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
