; Convert a null-terminated wide sequence without splitting a character.
bits 64
default rel

global __al_wcs_convert:function
extern __al_mb_encode:function

section .text.__al_wcs_convert alloc exec nowrite progbits
__al_wcs_convert:
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
    jz .measure
    cmp r15, r14
    jae .bounded
.measure:
    mov esi, [r12]
    mov [rsp], esi
    xor edi, edi
    mov rdx, r13
    xor ecx, ecx                ; use current LC_CTYPE
    call __al_mb_encode
    test rax, rax
    js .invalid
    test rbx, rbx
    jz .check_null
    mov r10, r14
    sub r10, r15
    cmp rax, r10
    ja .bounded
    lea rdi, [rbx + r15]
    mov esi, [rsp]
    mov rdx, r13
    xor ecx, ecx                ; use current LC_CTYPE
    call __al_mb_encode
    test rax, rax
    js .invalid
.check_null:
    cmp dword [rsp], 0
    je .terminated
    add r15, rax
    add r12, 4
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
