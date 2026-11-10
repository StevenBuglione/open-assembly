bits 64
default rel
global sse2_scalar_crosses_frame:function
section .text
sse2_scalar_crosses_frame:
    sub rsp, 8
    cvtsd2ss xmm0, qword [rsp + 4]
    add rsp, 8
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
