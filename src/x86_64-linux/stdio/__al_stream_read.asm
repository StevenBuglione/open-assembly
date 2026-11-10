; Apply byte orientation and pass through to the buffered byte read.
bits 64
default rel

global __al_stream_read:function
extern __al_stream_read_raw:function

section .text.__al_stream_read alloc exec nowrite progbits
__al_stream_read:
    test rdx, rdx
    jz .empty
    cmp dword [rdi + 128], 1
    je .wrong_orientation
    mov dword [rdi + 128], -1
    sub rsp, 8
    call __al_stream_read_raw
    add rsp, 8
    ret
.wrong_orientation:
    xor eax, eax
    mov edx, 1
    ret
.empty:
    xor eax, eax
    xor edx, edx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
