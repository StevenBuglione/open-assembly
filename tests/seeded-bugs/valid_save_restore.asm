; Accept aligned calls and caller values restored from the stack.
bits 64
default rel

section .text
global test_valid_save_restore:function
extern external_target
test_valid_save_restore:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8
    mov rbx, rdi
    call external_target
    add rsp, 8
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
