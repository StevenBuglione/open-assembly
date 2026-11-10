; Apply byte orientation and pass through to the buffered byte write.
bits 64
default rel

global __al_stream_write:function
extern __al_stream_write_raw:function

section .text.__al_stream_write alloc exec nowrite progbits
__al_stream_write:
    cmp dword [rdi + 128], 1
    je .wrong_orientation
    mov dword [rdi + 128], -1
    sub rsp, 8
    call __al_stream_write_raw
    add rsp, 8
    ret
.wrong_orientation:
    xor eax, eax
    mov edx, 1
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
