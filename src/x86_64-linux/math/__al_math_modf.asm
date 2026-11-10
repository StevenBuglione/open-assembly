; Split kind/rawlo/rawhi into fraction return and integer output through rcx.
bits 64
default rel

global __al_math_modf:function
extern __al_fp_decode:function
extern __al_fp_quiet:function
extern __al_math_effects:function
extern __al_fp_pack_exact:function

section .text.__al_math_modf alloc exec nowrite progbits
__al_math_modf:
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
    jz .both_same
    cmp r8d, 4
    je .both_same
    mov r15d, ecx
    cmp r8d, 3
    je .integral
    test edx, edx
    jns .integral

    mov [rsp + 8], edx
    mov ecx, edx
    neg ecx
    cmp ecx, 64
    jae .fraction_only
    mov rsi, rax
    shr rsi, cl
    mov r9, rsi
    shl r9, cl
    xor rax, r9
    mov [rsp], rax
    mov edi, ebx
    xor edx, edx
    mov ecx, r15d
    call __al_fp_pack_exact
    mov r12, rax
    mov r13d, edx
    mov edi, ebx
    mov rsi, [rsp]
    mov edx, [rsp + 8]
    mov ecx, r15d
    call __al_fp_pack_exact
    jmp .store
.fraction_only:
    mov [rsp], r12
    mov [rsp + 8], r13d
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    mov ecx, r15d
    call __al_fp_pack_exact
    mov r12, rax
    mov r13d, edx
    mov rax, [rsp]
    mov edx, [rsp + 8]
    jmp .store
.integral:
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    mov ecx, r15d
    call __al_fp_pack_exact
    jmp .store
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
.both_same:
    mov rax, r12
    mov edx, r13d
.store:
    test ebx, ebx
    jz .store_single
    mov [r14], r12
    cmp ebx, 1
    je .done
    mov [r14 + 8], r13w
    jmp .done
.store_single:
    mov [r14], r12d
.done:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
