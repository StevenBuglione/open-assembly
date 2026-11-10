; Convert a null-terminated multibyte sequence. Return count and next source pointer.
bits 64
default rel

global __al_mbs_convert:function
extern __al_mb_decode:function

section .text.__al_mbs_convert alloc exec nowrite progbits
__al_mbs_convert:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rcx
    mov r14, rdx
    xor r15d, r15d
.character:
    test rbx, rbx
    jz .decode
    cmp r15, r14
    jae .bounded
.decode:
    mov rdi, r12
    mov esi, 4
    mov rdx, r13
    call __al_mb_decode
    test rax, rax
    js .invalid
    test rbx, rbx
    jz .check_null
    mov [rbx + r15*4], edx
.check_null:
    test rax, rax
    jz .terminated
    add r12, rax
    inc r15
    jmp .character
.terminated:
    xor r12d, r12d
.bounded:
    mov rax, r15
.invalid:
    mov rdx, r12
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
