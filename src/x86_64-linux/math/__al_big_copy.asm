; Original copy between distinct bignums. rdi = destination, rsi = source.
bits 64
default rel

global __al_big_copy:function

section .text.__al_big_copy alloc exec nowrite progbits
__al_big_copy:
    mov rdx, [rsi]
    mov [rdi], rdx
    xor ecx, ecx
.next:
    cmp rcx, rdx
    jae .done
    mov eax, [rsi + rcx*4 + 8]
    mov [rdi + rcx*4 + 8], eax
    inc rcx
    jmp .next
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
