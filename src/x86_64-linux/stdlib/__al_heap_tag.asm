; Original allocator integrity tag. rdi points to a 32-byte slot header.
bits 64
default rel

global __al_heap_tag:function
extern __al_heap_seed:data

section .text.__al_heap_tag alloc exec nowrite progbits
__al_heap_tag:
    mov rax, [rdi]                ; owner and state bits
    xor rax, rdi
    rol rax, 17
    mov rdx, [rdi + 8]            ; requested size
    rol rdx, 31
    xor rax, rdx
    xor rax, [rdi + 16]           ; next free slot or direct mapping length
    xor rax, [rel __al_heap_seed]
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
