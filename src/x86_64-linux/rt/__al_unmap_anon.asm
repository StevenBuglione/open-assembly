; Original kernel wrapper. rdi = mapping address, rsi = length.
; A failure for a validated owned mapping is fatal.
bits 64
default rel

global __al_unmap_anon:function
extern __al_syscall:function
extern __al_panic:function

section .text.__al_unmap_anon alloc exec nowrite progbits
__al_unmap_anon:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov rdx, rsi
    mov rsi, rdi
    mov edi, 11                   ; __NR_munmap
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    test rax, rax
    jnz .fail
    add rsp, 16
    pop rbp
    ret
.fail:
    lea rdi, [rel failure]
    mov esi, 29
    call __al_panic
    ud2

section .rodata.__al_unmap_anon alloc noexec nowrite progbits
failure:
    db "open-assembly: munmap failed", 10

section .note.GNU-stack noalloc noexec nowrite progbits
