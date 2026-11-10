; The initialized thread pointer identifies the owner of a stream lock.
bits 64
default rel

global __al_stream_owner:function

section .text.__al_stream_owner alloc exec nowrite progbits
__al_stream_owner:
    mov rax, [fs:0]
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
