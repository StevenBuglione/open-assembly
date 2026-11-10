; Scale finite kind/rawlo/rawhi by a signed 64-bit power of two in rcx.
bits 64
default rel

global __al_math_scale:function
extern __al_fp_decode:function
extern __al_fp_quiet:function
extern __al_math_effects:function
extern __al_fp_round_shift:function
extern __al_fp_pack_exact:function
extern __al_fp_special:function
extern fegetround:function

section .text.__al_math_scale alloc exec nowrite progbits
__al_math_scale:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32
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
    mov r15d, ecx
    mov [rsp], rax
    mov [rsp + 8], edx
    bsr r9, rax
    test ebx, ebx
    jz .single
    cmp ebx, 1
    je .double
    mov r10d, 16383
    mov r11d, -16445
    mov esi, -16382
    jmp .bounds
.double:
    mov r10d, 1023
    mov r11d, -1074
    mov esi, -1022
    jmp .bounds
.single:
    mov r10d, 127
    mov r11d, -149
    mov esi, -126
.bounds:
    mov [rsp + 12], r11d          ; exponent of the minimum subnormal
    sub esi, r11d
    mov [rsp + 16], esi           ; leading-bit index of the minimum normal
    add esi, r11d

    ; Beyond these bounds no canonical operand can reach the normal range.
    cmp r14, 65536
    jg .overflow
    cmp r14, -65536
    jl .far_tiny
    add edx, r14d
    add r9d, edx
    cmp r9d, r10d
    jg .overflow
    cmp r9d, esi
    jl .subnormal
.pack_exact:
    mov edi, ebx
    mov rsi, rax
    mov ecx, r15d
    call __al_fp_pack_exact
    jmp .done
.far_tiny:
    mov r11d, 65
    jmp .tiny
.subnormal:
    sub r11d, edx
    js .pack_exact
.tiny:
    mov [rsp + 20], r11d
    call fegetround
    mov ecx, eax
    mov edx, r15d
    mov esi, [rsp + 20]
    mov rdi, [rsp]
    call __al_fp_round_shift
    mov r12, rax
    test edx, edx
    jz .pack_tiny
    mov edi, 48
    mov esi, 34
    test rax, rax
    jz .tiny_effects
    bsr r9, rax
    cmp r9d, [rsp + 16]
    jb .tiny_effects
    mov edi, 32
    xor esi, esi
.tiny_effects:
    call __al_math_effects
.pack_tiny:
    mov edi, ebx
    mov rsi, r12
    mov edx, [rsp + 12]
    mov ecx, r15d
    call __al_fp_pack_exact
    jmp .done

.overflow:
    call fegetround
    xor r12d, r12d
    test eax, eax
    jz .overflow_effects
    mov r12d, 1
    cmp eax, 3072
    je .overflow_effects
    test r15d, r15d
    jz .positive_overflow
    cmp eax, 1024
    jne .overflow_effects
    xor r12d, r12d
    jmp .overflow_effects
.positive_overflow:
    cmp eax, 2048
    jne .overflow_effects
    xor r12d, r12d
.overflow_effects:
    mov edi, 40
    mov esi, 34
    call __al_math_effects
    mov edi, ebx
    mov esi, r12d
    mov edx, r15d
    call __al_fp_special
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
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
