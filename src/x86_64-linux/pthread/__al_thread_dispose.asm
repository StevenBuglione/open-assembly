; Original parent/claimant storage release. The target has no kernel users.
bits 64
default rel

global __al_thread_dispose:function
extern __al_unmap_anon:function

section .text.__al_thread_dispose alloc exec nowrite progbits
__al_thread_dispose:
    push rbx
    mov rbx, rdi
    mov rdi, [rbx + 0x60]
    test rdi, rdi
    jz .tls
    mov rsi, [rbx + 0x68]
    call __al_unmap_anon
.tls:
    mov rdi, [rbx + 0x50]
    mov rsi, [rbx + 0x58]
    call __al_unmap_anon
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
