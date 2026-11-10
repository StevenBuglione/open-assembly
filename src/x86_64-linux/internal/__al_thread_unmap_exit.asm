; Original stackless detached exit. Inputs: TLS base and length, optional
; stack base and length. Caller blocked signals and cleared the kernel TID pointer.
bits 64
default rel

global __al_thread_unmap_exit:function

section .text.__al_thread_unmap_exit alloc exec nowrite progbits
__al_thread_unmap_exit:
    mov r8, rdx
    mov r9, rcx
    mov eax, 11                   ; __NR_munmap
    syscall
    test r8, r8
    jz .exit
    mov rdi, r8
    mov rsi, r9
    mov eax, 11
    syscall
.exit:
    xor edi, edi
    mov eax, 60                   ; __NR_exit
    syscall
    ud2

section .note.GNU-stack noalloc noexec nowrite progbits
