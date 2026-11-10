; Original registry retirement. rsi zero drops a snapshot pin. A nonzero
; value retires a closed and already unlocked stream.
bits 64
default rel

global __al_stream_unpin:function
extern __al_stdio_lock:data
extern __al_lock:function
extern __al_unlock:function
extern free:function

section .text.__al_stream_unpin alloc exec nowrite progbits
__al_stream_unpin:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    xor r13d, r13d
    lea rdi, [rel __al_stdio_lock]
    call __al_lock
    test r12, r12
    jnz .retire
    sub dword [rbx + 100], 1
    jmp .consider
.retire:
    or qword [rbx + 120], 2
.consider:
    cmp qword [rbx + 120], 3     ; heap-owned and retired
    jne .unlock
    cmp dword [rbx + 100], 0
    jne .unlock
    mov r13d, 1
.unlock:
    lea rdi, [rel __al_stdio_lock]
    call __al_unlock
    test r13d, r13d
    jz .done
    mov rdi, rbx
    call free
.done:
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
