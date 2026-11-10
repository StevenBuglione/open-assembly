; Compute cbrt for r9d=3 or hypot for r9d=2. Same-kind words in edi/rsi/edx and rcx/r8d.
bits 64
default rel

global __al_math_root:function
extern __al_fp_decode:function
extern __al_fp_special:function
extern __al_fp_quiet:function
extern __al_math_effects:function
extern __al_lock:function
extern __al_unlock:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_big_add:function
extern __al_root_round:function

section .text.__al_math_root alloc exec nowrite progbits
__al_math_root:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 48
    mov ebx, edi
    mov r12, rsi
    mov r13d, edx
    mov r14, rcx
    mov r15d, r8d
    mov [rsp], r9
    call __al_fp_decode
    mov [rsp + 8], rax
    mov [rsp + 16], edx
    mov [rsp + 20], r8d
    mov [rsp + 24], ecx
    cmp r8d, 5
    je .signaling
    cmp dword [rsp], 3
    je .cube

    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    call __al_fp_decode
    cmp r8d, 5
    je .signaling_y
    cmp r8d, 3
    je .infinite
    cmp dword [rsp + 20], 3
    je .infinite
    cmp dword [rsp + 20], 4
    je .original
    cmp r8d, 4
    je .return_y
    cmp dword [rsp + 20], 0
    je .only_y
    test r8d, r8d
    jz .absolute

    ; Each input is nonzero. Keep the sum of squares exact on the
    ; quantum of the lower of the two squared exponents.
    mov [rsp + 32], rax
    add edx, edx
    mov [rsp + 40], edx
    shl dword [rsp + 16], 1
    mov eax, [rsp + 16]
    cmp eax, edx
    jle .common
    mov eax, edx
.common:
    mov [rsp + 28], eax
    mov dword [rsp + 24], 0
    lea rdi, [rel root_lock]
    call __al_lock
    mov rax, [rsp + 8]
    mul rax
    lea r12, [rel radicand]
    mov rdi, r12
    mov rsi, rax
    call __al_big_init128
    mov rdi, r12
    mov esi, [rsp + 16]
    sub esi, [rsp + 28]
    call __al_big_left
    mov rax, [rsp + 32]
    mul rax
    lea r13, [rel addend]
    mov rdi, r13
    mov rsi, rax
    call __al_big_init128
    mov rdi, r13
    mov esi, [rsp + 40]
    sub esi, [rsp + 28]
    call __al_big_left
    mov rdi, r12
    mov rsi, r13
    call __al_big_add
    jmp .round

.cube:
    test r8d, r8d
    jz .original
    cmp r8d, 2
    ja .original
    mov [rsp + 28], edx
    lea rdi, [rel root_lock]
    call __al_lock
    lea r12, [rel radicand]
    mov rdi, r12
    mov rsi, [rsp + 8]
    xor edx, edx
    call __al_big_init128
.round:
    mov rdi, r12
    movsxd rsi, dword [rsp + 28]
    mov edx, ebx
    mov ecx, [rsp + 24]
    mov r8, [rsp]
    lea r9, [rel power_scratch]
    call __al_root_round
    mov r12, rax
    mov r13d, edx
    mov [rsp + 44], ecx
    lea rdi, [rel root_lock]
    call __al_unlock
    mov edi, [rsp + 44]
    xor esi, esi
    test edi, 24
    jz .effects
    mov esi, 34
.effects:
    call __al_math_effects
    jmp .original

.infinite:
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    call __al_fp_special
    jmp .done
.only_y:
    mov r12, r14
    mov r13d, r15d
.absolute:
    test ebx, ebx
    jz .single_abs
    cmp ebx, 1
    je .double_abs
    and r13d, 0x7fff
    jmp .original
.double_abs:
    shl r12, 1
    shr r12, 1
    jmp .original
.single_abs:
    and r12d, 0x7fffffff
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
    jmp .original
.return_y:
    mov r12, r14
    mov r13d, r15d
.original:
    mov rax, r12
    mov edx, r13d
.done:
    add rsp, 48
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .bss.__al_math_root alloc noexec write nobits align=8
root_lock:
    resq 1
radicand:
    resq 1281
addend:
    resq 1281
power_scratch:
    resq 8

section .note.GNU-stack noalloc noexec nowrite progbits
