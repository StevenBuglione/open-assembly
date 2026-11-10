; Original implementation. See docs/adr/0002-runtime-abi.md.
bits 64
default rel

global __al_syscall_result:function
extern __errno_location:function

section .text.__al_syscall_result alloc exec nowrite progbits
__al_syscall_result:
    cmp rdi, -4095
    jae .error
    mov rax, rdi
    ret

.error:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    neg edi
    mov [rsp], edi
    call __errno_location
    mov edx, [rsp]
    mov [rax], edx
    mov rax, -1
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
