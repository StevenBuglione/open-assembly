bits 64
default rel
global sse2_conversion_clobbers_rbx:function
section .text
sse2_conversion_clobbers_rbx:
    cvttsd2si ebx, xmm0
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
