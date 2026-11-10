; Decode a scalar to optional output and select default state slot r8d.
bits 64
default rel

global __al_mbr_scalar:function
extern __al_mbstate_default:function
extern __al_mb_decode:function

section .text.__al_mbr_scalar alloc exec nowrite progbits
__al_mbr_scalar:
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov r15, rcx
    mov edi, r8d
    test r15, r15
    jnz .input
    call __al_mbstate_default
    mov r15, rax
.input:
    test r13, r13
    jnz .decode
    xor r12d, r12d
    lea r13, [rel null_byte]
    mov r14d, 1
.decode:
    mov rdi, r13
    mov rsi, r14
    mov rdx, r15
    xor ecx, ecx                ; use current LC_CTYPE
    call __al_mb_decode
    test rax, rax
    js .done
    test r12, r12
    jz .done
    mov [r12], edx
.done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    ret

section .rodata alloc noexec nowrite progbits
null_byte: db 0

section .note.GNU-stack noalloc noexec nowrite progbits
