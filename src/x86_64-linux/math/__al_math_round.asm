; Round kind/rawlo/rawhi to floating integral value. ecx selects fixed mode or rint/nearbyint.
bits 64
default rel

global __al_math_round:function
extern __al_fp_decode:function
extern __al_fp_quiet:function
extern __al_math_effects:function
extern __al_fp_round_shift:function
extern __al_fp_pack_exact:function
extern fegetround:function

section .text.__al_math_round alloc exec nowrite progbits
__al_math_round:
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
    cmp r8d, 5
    je .signaling
    test r8d, r8d
    jz .original
    cmp r8d, 2
    ja .original
    test edx, edx
    jns .original

    mov r15, rcx
    mov [rsp], rax
    mov [rsp + 8], edx
    cmp r14d, 4096
    jbe .mode_ready
    call fegetround
    mov ecx, eax
    jmp .shift
.mode_ready:
    mov ecx, r14d
.shift:
    mov rdi, [rsp]
    mov esi, [rsp + 8]
    neg esi
    mov edx, r15d
    call __al_fp_round_shift
    mov r12, rax
    test edx, edx
    jz .pack
    cmp r14d, 4097
    jne .pack
    mov edi, 32
    xor esi, esi
    call __al_math_effects
.pack:
    mov edi, ebx
    mov rsi, r12
    xor edx, edx
    mov ecx, r15d
    call __al_fp_pack_exact
    jmp .done
.signaling:
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    call __al_fp_quiet
    mov r12, rax
    mov r13d, edx
    mov edi, 1
    xor esi, esi
    call __al_math_effects
.original:
    mov rax, r12
    mov edx, r13d
.done:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
