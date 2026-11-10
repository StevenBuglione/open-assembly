; Compute positive difference of same-kind operands via a single exact fused evaluation.
bits 64
default rel

global __al_math_fdim:function
extern __al_fp_compare:function
extern __al_math_fma:function
extern __al_fp_quiet:function
extern __al_math_effects:function

section .text.__al_math_fdim alloc exec nowrite progbits
__al_math_fdim:
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
    mov r15d, r8d
    call __al_fp_compare
    cmp edx, 5
    je .signaling
    cmp ecx, 5
    je .signaling_y
    cmp eax, 2
    je .unordered
    cmp eax, 1
    jne .zero
    mov edi, ebx
    mov rsi, r12
    mov rcx, r14
    xor r8d, r8d
    test ebx, ebx
    jz .single
    cmp ebx, 1
    je .double
    mov rdx, 0x8000000000000000
    xor r15d, 0x8000
    mov r8, r15
    shl r8, 32
    mov eax, 0x3fff0000
    or r8, rax
    or r8, r13
    jmp .evaluate
.double:
    mov rdx, 0x3ff0000000000000
    mov rax, 0x8000000000000000
    xor rcx, rax
    jmp .evaluate
.single:
    mov edx, 0x3f800000
    xor ecx, 0x80000000
.evaluate:
    call __al_math_fma
    jmp .done
.zero:
    xor eax, eax
    xor edx, edx
    jmp .done
.unordered:
    cmp edx, 4
    je .original
    mov r12, r14
    mov r13d, r15d
    jmp .original
.signaling_y:
    mov r12, r14
    mov r13d, r15d
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
