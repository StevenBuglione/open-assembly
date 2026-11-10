; Original final stream release. Caller owns the stream.
bits 64
default rel

global __al_stream_unlock_all:function
extern __al_unlock:function

section .text.__al_stream_unlock_all alloc exec nowrite progbits
__al_stream_unlock_all:
    mov qword [rdi + 104], 0
    mov qword [rdi + 112], 0
    add rdi, 96
    sub rsp, 8
    call __al_unlock
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
