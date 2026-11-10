; Select minimum for r9d=0 or maximum for r9d=1 from a same-kind encoded pair.
bits 64
default rel

global __al_math_minmax:function
extern __al_fp_compare:function
extern __al_fp_quiet:function
extern __al_math_effects:function

section .text.__al_math_minmax alloc exec nowrite progbits
__al_math_minmax:
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
    mov [rsp], r9d
    call __al_fp_compare
    cmp edx, 5
    je .signaling
    cmp ecx, 5
    je .signal_y
    cmp eax, 2
    je .quiet_nan
    test eax, eax
    jz .equal
    cmp dword [rsp], 0
    je .min
    test eax, eax
    jg .choose_x
    jmp .choose_y
.min:
    test eax, eax
    jl .choose_x
    jmp .choose_y
.equal:
    ; With equal nonzero values the canonical words are identical.
    cmp dword [rsp], 0
    je .minimum_zero
    and r12, r14
    and r13d, r15d
    jmp .choose_x
.minimum_zero:
    or r12, r14
    or r13d, r15d
    jmp .choose_x
.quiet_nan:
    cmp ecx, 4
    je .choose_x
    jmp .choose_y
.signal_y:
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
    jmp .choose_x
.choose_y:
    mov r12, r14
    mov r13d, r15d
.choose_x:
    mov rax, r12
    mov edx, r13d
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
