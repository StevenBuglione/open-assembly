; Round a result within half a step of encoded x, with true result higher/lower for rcx +1/-1.
bits 64
default rel

global __al_math_tiny_adjust:function
extern __al_fp_decode:function
extern fegetround:function
extern __al_fp_special:function
extern __al_math_next:function
extern __al_math_effects:function

section .text.__al_math_tiny_adjust alloc exec nowrite progbits
__al_math_tiny_adjust:
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
    mov r15d, ecx
    mov [rsp], r8d
    mov eax, r14d
    shr eax, 31
    mov [rsp + 4], eax           ; true result lies below x
    call fegetround
    cmp eax, 3072
    je .toward_zero
    cmp eax, 1024
    je .downward
    cmp eax, 2048
    jne .original_flags
    test r14d, r14d
    jg .step
    jmp .original_flags
.downward:
    test r14d, r14d
    jl .step
    jmp .original_flags
.toward_zero:
    cmp r15d, [rsp + 4]
    je .original_flags
.step:
    xor r8d, r8d
    xor r9d, r9d
    cmp r15d, [rsp + 4]
    jne .toward_target
    mov edi, ebx
    xor esi, esi
    mov edx, r15d
    call __al_fp_special
    mov r8, rax
    mov r9d, edx
.toward_target:
    mov edi, ebx
    mov rsi, r12
    mov edx, r13d
    mov ecx, ebx
    call __al_math_next
    mov r12, rax
    mov r13d, edx
    mov edi, ebx
    mov rsi, r12
    call __al_fp_decode
    cmp r8d, 1
    jbe .original                ; next already published the tiny effects
    mov edi, 32
    xor esi, esi
    jmp .effects
.original_flags:
    mov edi, 32
    xor esi, esi
    cmp dword [rsp], 1
    ja .effects
    or edi, 16
    mov esi, 34
.effects:
    call __al_math_effects
.original:
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
