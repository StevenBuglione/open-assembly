; Original errno helper. rdi = positive error, returns -1.
bits 64
default rel

global __al_stdio_errno:function
extern __errno_location:function

section .text.__al_stdio_errno alloc exec nowrite progbits
__al_stdio_errno:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov [rsp], edi
    call __errno_location
    mov edx, [rsp]
    mov [rax], edx
    mov rax, -1
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
