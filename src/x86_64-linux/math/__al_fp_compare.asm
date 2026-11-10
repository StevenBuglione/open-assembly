; Compare same-kind words in edi/rsi/edx and rcx/r8d. eax -1/0/1/2 and edx/ecx operand classes.
bits 64
default rel

global __al_fp_compare:function
extern __al_fp_decode:function

section .text.__al_fp_compare alloc exec nowrite progbits
__al_fp_compare:
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
    call __al_fp_decode
    mov [rsp], ecx
    mov [rsp + 4], r8d
    mov edi, ebx
    mov rsi, r14
    mov edx, r15d
    call __al_fp_decode
    mov edx, [rsp + 4]
    cmp edx, 4
    jae .unordered
    cmp r8d, 4
    jae .unordered
    cmp ecx, [rsp]
    jne .opposite_sign

    ; With matching signs the canonical encoding orders by magnitude.
    cmp ebx, 2
    jne .significands
    cmp r13d, r15d
    ja .larger_magnitude
    jb .smaller_magnitude
.significands:
    cmp r12, r14
    ja .larger_magnitude
    jb .smaller_magnitude
    jmp .equal
.opposite_sign:
    test edx, edx
    jnz .signed_order
    test r8d, r8d
    jz .equal
.signed_order:
    cmp dword [rsp], 0
    je .greater
    jmp .less
.larger_magnitude:
    test ecx, ecx
    jnz .less
    jmp .greater
.smaller_magnitude:
    test ecx, ecx
    jnz .greater
.less:
    mov eax, -1
    jmp .done
.greater:
    mov eax, 1
    jmp .done
.unordered:
    mov eax, 2
    jmp .done
.equal:
    xor eax, eax
.done:
    mov ecx, r8d
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
