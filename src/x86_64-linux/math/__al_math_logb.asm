; Extract the unbiased leading-bit exponent. ecx nonzero selects ilogb integer result.
bits 64
default rel

global __al_math_logb:function
extern __al_fp_decode:function
extern __al_fp_pack_exact:function
extern __al_fp_special:function
extern __al_math_effects:function
extern __al_fp_quiet:function

section .text.__al_math_logb alloc exec nowrite progbits
__al_math_logb:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov ebx, edi
    mov r12, rsi
    mov r13d, edx
    mov r14, rcx
    call __al_fp_decode
    test r8d, r8d
    jz .zero
    cmp r8d, 2
    ja .nonfinite
    bsr r9, rax
    lea eax, [rdx + r9]
    test r14d, r14d
    jnz .done
    xor ecx, ecx
    test eax, eax
    jns .pack
    neg eax
    mov ecx, 1
.pack:
    mov edi, ebx
    mov esi, eax
    xor edx, edx
    call __al_fp_pack_exact
    jmp .done
.zero:
    test r14d, r14d
    jnz .invalid
    mov edi, 4
    mov esi, 34
    call __al_math_effects
    mov edi, ebx
    xor esi, esi
    mov edx, 1
    call __al_fp_special
    jmp .done
.nonfinite:
    test r14d, r14d
    jnz .invalid
    cmp r8d, 5
    je .signaling
    cmp r8d, 3
    jne .original
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    call __al_fp_special
    jmp .done
.invalid:
    mov r15d, 0x80000000
    cmp r8d, 3
    jne .raise_invalid
    mov r15d, 0x7fffffff
.raise_invalid:
    mov edi, 1
    mov esi, 33
    call __al_math_effects
    mov eax, r15d
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
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
