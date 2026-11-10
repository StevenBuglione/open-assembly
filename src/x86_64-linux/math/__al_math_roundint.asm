; Convert encoded x to signed long. ecx zero uses active rounding and raises inexact.
bits 64
default rel

global __al_math_roundint:function
extern __al_fp_decode:function
extern __al_fp_round_shift:function
extern __al_math_effects:function
extern fegetround:function

section .text.__al_math_roundint alloc exec nowrite progbits
__al_math_roundint:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov ebx, edi
    mov r12, rsi
    mov r13d, edx
    mov r14, rcx
    call __al_fp_decode
    test r8d, r8d
    jz .zero
    cmp r8d, 2
    ja .invalid
    mov r15d, ecx
    test edx, edx
    js .fraction

    bsr r9, rax
    add r9d, edx
    cmp r9d, 63
    ja .invalid
    mov ecx, edx
    shl rax, cl
    xor edx, edx
    jmp .check_sign
.fraction:
    mov [rsp], rax
    mov [rsp + 8], edx
    mov ecx, 4096
    test r14d, r14d
    jnz .shift
    call fegetround
    mov ecx, eax
.shift:
    mov rdi, [rsp]
    mov esi, [rsp + 8]
    neg esi
    mov edx, r15d
    call __al_fp_round_shift
.check_sign:
    test r15d, r15d
    jnz .negative
    test rax, rax
    js .invalid
    jmp .finish
.negative:
    neg rax
    test rax, rax
    jg .invalid
.finish:
    test edx, edx
    jz .done
    test r14d, r14d
    jnz .done
    mov r12, rax
    mov edi, 32
    xor esi, esi
    call __al_math_effects
    mov rax, r12
    jmp .done
.zero:
    xor eax, eax
    jmp .done
.invalid:
    mov edi, 1
    mov esi, 33
    call __al_math_effects
    mov rax, 0x8000000000000000
.done:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
