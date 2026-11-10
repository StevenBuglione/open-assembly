; Return a pattern/input unit in EAX and its byte width in EDX.
; ESI bit zero selects UTF-8 and bit one selects case folding. ECX returns
; the original unit. Invalid UTF-8 bytes occupy a private range.
bits 64
default rel

global __al_fnmatch_unit:function
extern __al_unicode_case:function

section .text.__al_fnmatch_unit alloc exec nowrite progbits
__al_fnmatch_unit:
    movzx eax, byte [rdi]
    mov edx, 1
    cmp eax, 128
    jb .return
    test esi, 1
    jz .return
    mov r11d, eax
    mov r9d, 128
    mov r10d, 191
    cmp eax, 194
    jb .invalid
    cmp eax, 223
    jbe .two
    cmp eax, 239
    jbe .three
    cmp eax, 244
    ja .invalid
    mov r8d, 3
    cmp eax, 240
    jne .four_upper
    mov r9d, 144
.four_upper:
    cmp eax, 244
    jne .four_payload
    mov r10d, 143
.four_payload:
    and eax, 7
    jmp .continuation
.three:
    mov r8d, 2
    cmp eax, 224
    jne .three_upper
    mov r9d, 160
.three_upper:
    cmp eax, 237
    jne .three_payload
    mov r10d, 159
.three_payload:
    and eax, 15
    jmp .continuation
.two:
    mov r8d, 1
    and eax, 31
.continuation:
    movzx ecx, byte [rdi + rdx]
    cmp ecx, r9d
    jb .invalid
    cmp ecx, r10d
    ja .invalid
    shl eax, 6
    and ecx, 63
    or eax, ecx
    inc edx
    dec r8d
    jz .return
    mov r9d, 128
    mov r10d, 191
    jmp .continuation
.invalid:
    lea eax, [r11 + 0x110000]
    mov edx, 1
.return:
    mov ecx, eax
    test esi, 2
    jnz .fold
    ret
.fold:
    push rbx
    push r12
    push r13
    mov ebx, edx
    mov r12d, eax
    mov r13d, esi
    and r13d, 1
    inc r13d
    mov edi, eax
    mov esi, 1
    mov edx, r13d
    call __al_unicode_case
    mov edi, eax
    xor esi, esi
    mov edx, r13d
    call __al_unicode_case
    mov ecx, r12d
    mov edx, ebx
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
