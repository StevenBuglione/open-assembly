; Original exponent suffix. rdi = destination, rsi = exponent,
; rdx = marker byte, rcx = minimum digits. Returns bytes written.
bits 64
default rel

global __al_fmt_exponent:function

section .text.__al_fmt_exponent alloc exec nowrite progbits
__al_fmt_exponent:
    mov [rdi], dl
    mov byte [rdi + 1], 43
    test rsi, rsi
    jns .magnitude
    mov byte [rdi + 1], 45
    neg rsi
.magnitude:
    mov rax, rsi
    mov r8d, 10
    lea r9, [rel scratch + 8]
    xor r10d, r10d
.digit:
    xor edx, edx
    div r8
    add dl, 48
    dec r9
    mov [r9], dl
    inc r10
    test rax, rax
    jnz .digit
.padding:
    cmp r10, rcx
    jae .copy_start
    dec r9
    mov byte [r9], 48
    inc r10
    jmp .padding
.copy_start:
    xor ecx, ecx
.copy:
    mov dl, [r9 + rcx]
    mov [rdi + rcx + 2], dl
    inc rcx
    cmp rcx, r10
    jb .copy
    lea rax, [r10 + 2]
    ret

section .bss.__al_fmt_exponent alloc noexec write nobits align=8
scratch:
    resb 8

section .note.GNU-stack noalloc noexec nowrite progbits
