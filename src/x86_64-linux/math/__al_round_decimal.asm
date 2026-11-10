; Original rounding of exact decimal digits to a signed retained count.
; rdi = digits, rsi = count, rdx = keep, rcx = mode, r8 = sign, r9 = order.
; Returns rounded count and order in rax and rdx, editing the digits.
bits 64
default rel

global __al_round_decimal:function

section .text.__al_round_decimal alloc exec nowrite progbits
__al_round_decimal:
    cmp rdx, rsi
    jge .unchanged
    mov r10, rdx
    test r10, r10
    jns .find_discarded
    xor r10d, r10d
.find_discarded:
    cmp r10, rsi
    jae .truncate
    cmp byte [rdi + r10], 48
    jne .inexact
    inc r10
    jmp .find_discarded
.inexact:
    test rcx, rcx
    jz .nearest
    cmp rcx, 1024
    je .downward
    cmp rcx, 2048
    jne .truncate
    test r8, r8
    jz .increment
    jmp .truncate
.downward:
    test r8, r8
    jnz .increment
    jmp .truncate
.nearest:
    test rdx, rdx
    js .truncate
    cmp byte [rdi + rdx], 53
    ja .increment
    jb .truncate
    lea r10, [rdx + 1]
.sticky:
    cmp r10, rsi
    jae .tie
    cmp byte [rdi + r10], 48
    jne .increment
    inc r10
    jmp .sticky
.tie:
    test rdx, rdx
    jz .truncate
    test byte [rdi + rdx - 1], 1
    jz .truncate

.increment:
    test rdx, rdx
    jle .least_quantum
    mov r10, rdx
.carry:
    dec r10
    cmp byte [rdi + r10], 57
    jne .add_one
    mov byte [rdi + r10], 48
    test r10, r10
    jnz .carry
    mov byte [rdi], 49
    inc r9
    jmp .truncate
.add_one:
    inc byte [rdi + r10]
    jmp .truncate
.least_quantum:
    mov byte [rdi], 49
    inc r9
    sub r9, rdx
    mov eax, 1
    mov rdx, r9
    ret

.truncate:
    test rdx, rdx
    jg .retained
    mov byte [rdi], 48
    mov eax, 1
    xor edx, edx
    ret
.retained:
    mov rax, rdx
    mov rdx, r9
    ret
.unchanged:
    mov rax, rsi
    mov rdx, r9
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
