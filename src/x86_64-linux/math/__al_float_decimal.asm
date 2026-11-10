; Original exact dyadic-to-decimal expansion. rdi = unsigned significand,
; rsi = binary exponent. Returns digit address, count, and decimal order
; in rax, rdx, rcx. Caller serializes this workspace.
bits 64
default rel

global __al_float_decimal:function
extern __al_big_muladd:function
extern __al_big_left:function
extern __al_big_divsmall:function

section .text.__al_float_decimal alloc exec nowrite progbits
__al_float_decimal:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13, rsi
    xor r14d, r14d
    lea rbx, [rel work]
    test r12, r12
    jz .zero
    mov [rbx + 8], r12
    mov qword [rbx], 1
    shr r12, 32
    jz .scale
    mov qword [rbx], 2
.scale:
    test r13, r13
    js .fraction
    mov rdi, rbx
    mov rsi, r13
    call __al_big_left
    jmp .prepare_digits
.fraction:
    neg r13
    mov r14, r13                  ; decimal scale
.power:
    mov rdi, rbx
    mov esi, 5
    xor edx, edx
    call __al_big_muladd
    dec r13
    jnz .power
.prepare_digits:
    lea r12, [rel digits + 22000]
.chunk:
    mov rdi, rbx
    mov esi, 1000000000
    call __al_big_divsmall
    mov r10, [rbx]                ; more high decimal chunks remain
    mov ecx, 9
    mov r8d, 10
.digit:
    xor edx, edx
    div r8
    add dl, 48
    dec r12
    mov [r12], dl
    test r10, r10
    jz .last_chunk
    dec ecx
    jnz .digit
    jmp .chunk
.last_chunk:
    test rax, rax
    jnz .digit
    lea rdx, [rel digits + 22000]
    sub rdx, r12
    mov rcx, rdx
    sub rcx, r14
    dec rcx
    mov rax, r12
    jmp .done
.zero:
    lea rax, [rel digits + 21999]
    mov byte [rax], 48
    mov edx, 1
    xor ecx, ecx
.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .bss.__al_float_decimal alloc noexec write nobits align=8
work:
    resq 1281
digits:
    resb 22000

section .note.GNU-stack noalloc noexec nowrite progbits
