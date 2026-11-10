; Original validation of the structural leap table. Corrections describe
; the transition time scale and do not alter public POSIX calendar seconds.
bits 64
default rel

global __al_tzif_leaps:function

section .text.__al_tzif_leaps alloc exec nowrite progbits
__al_tzif_leaps:
    mov r8, [rdi + 88]
    test r8, r8
    jz .valid
    mov r9, [rdi + 80]
    mov r10, [rdi + 72]
    mov r11, -1                  ; previous occurrence
    xor esi, esi                 ; previous correction
    xor ecx, ecx                 ; record index
.next:
    cmp r10, 8
    je .wide
    mov eax, [r9]
    bswap eax
    movsxd rax, eax
    jmp .ordered
.wide:
    mov rax, [r9]
    bswap rax
.ordered:
    cmp rax, r11
    jle .invalid
    mov r11, rax
    mov eax, [r9 + r10]
    bswap eax
    movsxd rax, eax
    mov rdx, rax
    sub rdx, rsi
    cmp rdx, 1
    je .advance
    cmp rdx, -1
    je .advance
    cmp qword [rdi + 96], 52      ; v4 may truncate or expire
    jne .invalid
    test rcx, rcx
    jnz .expiry
    test rax, rax
    jnz .advance
    jmp .invalid
.expiry:
    cmp r8, 1
    jne .invalid
    test rdx, rdx
    jnz .invalid
.advance:
    mov rsi, rax
    lea r9, [r9 + r10 + 4]
    inc rcx
    dec r8
    jnz .next
.valid:
    xor eax, eax
    ret
.invalid:
    mov eax, -1
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
