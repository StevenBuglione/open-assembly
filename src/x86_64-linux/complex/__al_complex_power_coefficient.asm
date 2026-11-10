; Reduce the dyadic rsi*2^rdx*ecx modulo eight into rdi. Scratch r8. Return scale and exact quadrant or -1.
bits 64
default rel

global __al_complex_power_coefficient:function
extern __al_big_init128:function
extern __al_big_copy:function
extern __al_big_right_sticky:function

section .text.__al_complex_power_coefficient alloc exec nowrite progbits
__al_complex_power_coefficient:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12, rdx
    mov r13, r8
    cmp r12, 3
    jge .zero
    mov rax, rsi
    mov ecx, ecx
    mul rcx
    test r12, r12
    js .fractional
    mov ecx, r12d
    shl rax, cl
    and eax, 7
    xor edx, edx
    xor r12d, r12d
    jmp .initialize
.fractional:
    mov ecx, 3
    sub ecx, r12d
    cmp ecx, 66
    jae .initialize
    cmp ecx, 64
    jb .low_bits
    sub ecx, 64
    mov r9d, 1
    shl r9, cl
    dec r9
    and rdx, r9
    jmp .initialize
.low_bits:
    mov r9d, 1
    shl r9, cl
    dec r9
    and rax, r9
    xor edx, edx
.initialize:
    mov rsi, rax
    call __al_big_init128
    test eax, eax
    jz .zero
    mov rdi, r13
    mov rsi, rbx
    call __al_big_copy
    mov rdi, r13
    mov rsi, r12
    neg rsi
    call __al_big_right_sticky
    mov edx, -1
    test eax, eax
    jnz .result
    mov eax, [r13 + 8]
    test eax, 1
    jnz .result
    shr eax, 1
    mov edx, eax
    jmp .result
.zero:
    mov qword [rbx], 0
    xor r12d, r12d
    xor edx, edx
.result:
    mov rax, r12
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
