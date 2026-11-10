; Original implementation. See docs/adr/0002-runtime-abi.md.
bits 64
default rel

global _start:function
global __al_initial_envp:data
global __al_auxv:data
extern __al_tls_init:function
extern main:function
extern exit:function

section .text._start alloc exec nowrite progbits
_start:
    cld
    xor ebp, ebp                   ; Mark the outermost frame.
    mov r12, [rsp]                 ; argc
    lea r13, [rsp + 8]             ; argv
    lea r14, [r13 + r12*8 + 8]      ; envp, after the argv terminator
    mov [rel __al_initial_envp], r14
    mov rdi, r14
.scan_env:
    mov rax, [rdi]
    add rdi, 8
    test rax, rax
    jnz .scan_env
    mov [rel __al_auxv], rdi        ; auxv, after the envp terminator
    call __al_tls_init

    mov edi, r12d
    mov rsi, r13
    mov rdx, r14
    call main
    mov edi, eax
    call exit
    ud2

section .bss.startup alloc noexec write nobits align=8
__al_initial_envp:
    resq 1
__al_auxv:
    resq 1

section .note.GNU-stack noalloc noexec nowrite progbits
