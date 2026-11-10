; Original thread-exit cleanup of this thread's active once frames.
bits 64
default rel

global __al_once_reset:function
extern __al_once_wake:function

section .text.__al_once_reset alloc exec nowrite progbits
__al_once_reset:
    push rbx
    mov rbx, [rdi + 0x910]
    mov qword [rdi + 0x910], 0
.next:
    test rbx, rbx
    jz .done
    mov rdi, [rbx + 8]
    mov rbx, [rbx]
    mov dword [rdi], 0            ; release on AMD64
    call __al_once_wake
    jmp .next
.done:
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
