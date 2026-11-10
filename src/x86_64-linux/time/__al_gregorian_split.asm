; Original Gregorian inverse. Input: signed epoch day. Return the full
; calendar year in RAX, zero-based year day in RDX, and era year in RCX.
bits 64
default rel

global __al_gregorian_split:function

section .text.__al_gregorian_split alloc exec nowrite progbits
__al_gregorian_split:
    push rbx
    lea rax, [rdi + 719528]
    cqo
    mov r9d, 146097
    idiv r9
    test rdx, rdx
    jns .era
    add rdx, 146097
    dec rax
.era:
    mov r11, rax
    mov rbx, rdx
    xor r8d, r8d                 ; inclusive lower year
    mov r10d, 400                ; exclusive upper year
    xor ecx, ecx                 ; first day of lower year
.year:
    lea rsi, [r8 + 1]
    cmp rsi, r10
    jae .found
    lea rsi, [r8 + r10]
    shr rsi, 1
    mov rdi, rsi
    imul rdi, 365
    lea rax, [rsi + 3]
    shr rax, 2
    add rdi, rax
    inc rdi                      ; year zero contributes a leap day
    lea rax, [rsi + 99]
    xor edx, edx
    mov r9d, 100
    div r9
    sub rdi, rax
    cmp rdi, rbx
    ja .earlier
    mov r8, rsi
    mov rcx, rdi
    jmp .year
.earlier:
    mov r10, rsi
    jmp .year
.found:
    mov rdx, rbx
    sub rdx, rcx
    imul r11, 400
    lea rax, [r11 + r8]
    mov rcx, r8
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
