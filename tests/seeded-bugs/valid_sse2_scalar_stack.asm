bits 64
default rel
global valid_sse2_scalar_stack:function
section .text
valid_sse2_scalar_stack:
    sub rsp, 8
    mov dword [rsp + 4], 0x3f800000
    cvtss2sd xmm0, dword [rsp + 4]
    addsd xmm0, xmm0
    subsd xmm0, xmm0
    add rsp, 8
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
