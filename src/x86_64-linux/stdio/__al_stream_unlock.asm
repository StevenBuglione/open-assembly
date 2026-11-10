; Original stream ownership release. A foreign owner cannot change the lock.
bits 64
default rel

global __al_stream_unlock:function
extern __errno_location:function
extern __al_stream_unlock_all:function

section .text.__al_stream_unlock alloc exec nowrite progbits
__al_stream_unlock:
    push rbx
    mov rbx, rdi
    call __errno_location
    cmp [rbx + 104], rax
    jne .done
    sub qword [rbx + 112], 1
    jnz .done
    mov rdi, rbx
    call __al_stream_unlock_all
.done:
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
