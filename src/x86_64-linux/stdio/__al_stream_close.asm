; Original locked disassociation. rdi = FILE, rsi != 0 keeps the object.
; The caller owns the stream and releases or retires the object afterwards.
bits 64
default rel

global __al_stream_close:function
extern __al_streams:data
extern __al_stdio_lock:data
extern __al_lock:function
extern __al_unlock:function
extern __al_stream_flush:function
extern __al_stdio_errno:function
extern close:function
extern free:function

section .text.__al_stream_close alloc exec nowrite progbits
__al_stream_close:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12, rsi
    xor r13d, r13d
    cmp qword [rbx], 0
    jl .already_closed

    ; Unlink before closing the descriptor. A concurrent popen child
    ; walks the registry and can never observe a reused descriptor here.
    lea rdi, [rel __al_stdio_lock]
    call __al_lock
    lea rax, [rel __al_streams]
.find:
    mov rdx, [rax]
    cmp rdx, rbx
    je .unlink
    test rdx, rdx
    jz .unlinked
    lea rax, [rdx + 16]
    jmp .find
.unlink:
    mov rdx, [rbx + 16]
    mov [rax], rdx
.unlinked:
    lea rdi, [rel __al_stdio_lock]
    call __al_unlock

    cmp qword [rbx + 56], 2
    jne .close_descriptor
    mov rdi, rbx
    call __al_stream_flush
    mov r13d, eax
.close_descriptor:
    mov rdi, [rbx]
    call close
    or r13d, eax
    mov qword [rbx], -1

    mov r14, [rbx + 8]
    test r14, 128                 ; separately allocated library buffer
    jz .release_buffer
    mov rdi, [rbx + 24]
    call free
.release_buffer:
    and r14, 8
    mov [rbx + 8], r14
    mov qword [rbx + 24], 0
    jmp .done
.already_closed:
    test r12, r12
    jnz .done
    mov edi, 9                    ; EBADF
    call __al_stdio_errno
    mov r13d, eax
.done:
    mov eax, r13d
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
