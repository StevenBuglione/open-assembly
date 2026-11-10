; Original day count from epoch. Inputs: full signed year, normalized
; zero-based month, and one-based day (which may extend past the month).
bits 64
default rel

global __al_gregorian_day:function

section .text.__al_gregorian_day alloc exec nowrite progbits
__al_gregorian_day:
    mov r8, rdx
    mov rax, rdi
    cqo
    mov r9d, 400
    idiv r9
    test rdx, rdx
    jns .era
    add rdx, 400
    dec rax
.era:
    imul rax, 146097
    mov r10, rax
    mov r11, rdx                  ; year within a 400-year era
    imul rdx, 365
    add r10, rdx
    test r11, r11
    jz .month
    lea rax, [r11 + 3]
    shr rax, 2
    add r10, rax
    inc r10                       ; year zero was a leap year
    lea rax, [r11 + 99]
    xor edx, edx
    mov r9d, 100
    div r9
    sub r10, rax
.month:
    lea rax, [rel month_days]
    movzx edx, word [rax + rsi*2]
    add r10, rdx
    cmp rsi, 1
    jbe .done
    test r11b, 3
    jnz .done
    cmp r11d, 100
    je .done
    cmp r11d, 200
    je .done
    cmp r11d, 300
    je .done
    inc r10
.done:
    lea rax, [r10 + r8 - 719529]
    ret

section .rodata.__al_gregorian_day alloc noexec nowrite progbits
month_days: dw 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334

section .note.GNU-stack noalloc noexec nowrite progbits
