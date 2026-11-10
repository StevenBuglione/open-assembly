; Decompose kind/rawlo/rawhi into fraction, storing signed exponent through rcx.
bits 64
default rel

global __al_math_frexp:function
extern __al_fp_decode:function
extern __al_fp_quiet:function
extern __al_math_effects:function
extern __al_fp_pack_exact:function

section .text.__al_math_frexp alloc exec nowrite progbits
__al_math_frexp:
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
    mov dword [r14], 0
    cmp r8d, 5
    je .signaling
    test r8d, r8d
    jz .original
    cmp r8d, 2
    ja .original

    bsr r9, rax
    lea r10d, [rdx + r9 + 1]
    mov [r14], r10d
    lea edx, [r9 + 1]
    neg edx
    mov edi, ebx
    mov rsi, rax
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
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
