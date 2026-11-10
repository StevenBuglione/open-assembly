; Return calling thread's default conversion state for slot edi.
bits 64
default rel

global __al_mbstate_default:function

section .text.__al_mbstate_default alloc exec nowrite progbits
__al_mbstate_default:
    mov edi, edi
    mov rax, [fs:0]
    lea rax, [rax + rdi*8 + 0x80]
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
