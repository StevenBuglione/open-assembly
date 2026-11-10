; Original explicit and implicit recursive stream ownership.
bits 64
default rel

global __al_stream_lock:function
extern __errno_location:function
extern __al_lock:function
extern __al_panic:function

section .text.__al_stream_lock alloc exec nowrite progbits
__al_stream_lock:
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rdi
    call __errno_location
    cmp [rbx + 104], rax
    je .recursive
    mov r12, rax
    lea rdi, [rbx + 96]
    call __al_lock
    mov qword [rbx + 112], 1
    mov [rbx + 104], r12
    jmp .done
.recursive:
    add qword [rbx + 112], 1
    jnc .done
    lea rdi, [rel failure]
    mov esi, 36
    call __al_panic
    ud2
.done:
    add rsp, 8
    pop r12
    pop rbx
    ret

section .rodata.__al_stream_lock alloc noexec nowrite progbits
failure: db "open-assembly: stream lock overflow", 10

section .note.GNU-stack noalloc noexec nowrite progbits
