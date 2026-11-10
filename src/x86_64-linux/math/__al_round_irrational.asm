; Round a nonzero irrational angle with the __al_float_round argument ABI. Return raw words and flags.
bits 64
default rel

global __al_round_irrational:function
extern __al_float_round:function
extern __al_fp_pack_biased:function

section .text.__al_round_irrational alloc exec nowrite progbits
__al_round_irrational:
    push rbx
    push r12
    sub rsp, 8
    mov ebx, r8d
    mov r12d, [rcx + 8]
    call __al_float_round
    or ecx, 32
    test edx, edx
    jnz .pack
    or ecx, 16
.pack:
    mov [rsp], ecx
    mov edi, ebx
    mov rsi, rax
    mov ecx, r12d
    call __al_fp_pack_biased
    mov ecx, [rsp]
    add rsp, 8
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
