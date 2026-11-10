; Accept an SSE2 leaf and a local conditional branch.
bits 64
default rel

section .text
global test_valid_sse2_leaf:function
test_valid_sse2_leaf:
    pxor xmm0, xmm0
    xor eax, eax
    test rdi, rdi
    jz .done
    inc eax
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
