; Original initial-runtime PATH selection. Borrow caller PATH or use our default.
bits 64
default rel

global __al_exec_path_env:function
extern getenv:function

section .text.__al_exec_path_env alloc exec nowrite progbits
__al_exec_path_env:
    sub rsp, 8
    lea rdi, [rel path_name]
    call getenv
    test rax, rax
    jnz .done
    lea rax, [rel default_path]
.done:
    add rsp, 8
    ret

section .rodata.__al_exec_path_env alloc noexec nowrite progbits
path_name: db "PATH", 0
default_path: db "/bin:/usr/bin", 0

section .note.GNU-stack noalloc noexec nowrite progbits
