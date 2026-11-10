; Original shell entry. rdi = command. Successful exec replaces the child;
; Linux failure exits it with status 127.
bits 64
default rel

global __al_shell_exec:function
global __al_shell_path:data
extern __al_syscall:function
extern environ:data
extern _exit:function

section .text.__al_shell_exec alloc exec nowrite progbits
__al_shell_exec:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    mov qword [rsp], 0
    lea rax, [rel shell_name]
    mov [rsp + 8], rax
    lea rax, [rel command_option]
    mov [rsp + 16], rax
    lea rax, [rel end_options]
    mov [rsp + 24], rax
    mov [rsp + 32], rdi
    mov qword [rsp + 40], 0
    lea rsi, [rel __al_shell_path]
    mov rcx, [rel environ]
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 59                   ; __NR_execve
    lea rdx, [rsp + 8]            ; shell argv, including the terminating NULL
    call __al_syscall
    mov edi, 127
    call _exit
    ud2

section .rodata.__al_shell_exec alloc noexec nowrite progbits
__al_shell_path:
    db '/bin/sh', 0
shell_name:
    db 'sh', 0
command_option:
    db '-c', 0
end_options:
    db '--', 0

section .note.GNU-stack noalloc noexec nowrite progbits
