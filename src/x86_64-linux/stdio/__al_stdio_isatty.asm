; Original startup-only terminal probe. rdi = fd. Returns raw ioctl result.
bits 64
default rel

global __al_stdio_isatty:function
extern __al_syscall:function

section .text.__al_stdio_isatty alloc exec nowrite progbits
__al_stdio_isatty:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov rsi, rdi
    mov edi, 16                   ; __NR_ioctl
    mov edx, 0x5401               ; TCGETS
    lea rcx, [rel terminal_state]
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    add rsp, 16
    pop rbp
    ret

section .bss.__al_stdio_isatty alloc noexec write nobits align=8
terminal_state:
    resb 64

section .note.GNU-stack noalloc noexec nowrite progbits
