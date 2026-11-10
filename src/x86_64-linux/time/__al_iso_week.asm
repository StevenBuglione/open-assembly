; Original ISO week calculation for validated zero-based year day and weekday.
; Inputs: calendar year, year day, Sunday-zero weekday. Outputs: ISO year in
; RAX, one-based ISO week in RDX. The Thursday determines the week-year.
bits 64
default rel

global __al_iso_week:function

section .text.__al_iso_week alloc exec nowrite progbits
__al_iso_week:
    mov r8, rdi
    test edx, edx
    jnz .weekday
    mov edx, 7
.weekday:
    lea r9, [rsi + 4]
    sub r9, rdx                  ; zero-based year day of the week's Thursday
    xor r11d, r11d
    test r9, r9
    jns .year_length
    dec r8
    mov r11d, 1
.year_length:
    mov ecx, 365
    mov rax, r8
    test al, 3
    jnz .adjust
    cqo
    mov r10d, 100
    idiv r10
    test rdx, rdx
    jnz .leap
    test al, 3
    jnz .adjust
.leap:
    inc ecx
.adjust:
    test r11d, r11d
    jz .check_next
    add r9, rcx
    jmp .week
.check_next:
    cmp r9, rcx
    jb .week
    inc r8
    sub r9, rcx
.week:
    mov rax, r9
    xor edx, edx
    mov ecx, 7
    div rcx
    lea rdx, [rax + 1]
    mov rax, r8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
