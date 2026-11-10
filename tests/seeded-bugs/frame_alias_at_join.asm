; Write through a frame alias whose provenance differs across a branch.
bits 64
default rel

section .text
global seed_frame_alias_at_join:function
seed_frame_alias_at_join:
    push rbp
    test edi, edi
    jnz .join
    mov rbp, rsp
.join:
    mov rdx, rbp
    mov [rdx + 8], rdi
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
