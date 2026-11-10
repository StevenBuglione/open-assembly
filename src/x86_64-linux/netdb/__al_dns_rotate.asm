; Return the next process-wide round-robin index for the supplied server count.
bits 64
default rel

global __al_dns_rotate:function

section .text.__al_dns_rotate alloc exec nowrite progbits
__al_dns_rotate:
    mov eax, 1
    lock xadd qword [rel next_rotation], rax
    xor edx, edx
    div rdi
    mov eax, edx
    ret

section .bss.__al_dns_rotate alloc noexec write nobits align=8
next_rotation: resq 1

section .note.GNU-stack noalloc noexec nowrite progbits
