; Original magnitude comparison. rdi = left, rsi = right.
bits 64
default rel

global __al_big_cmp:function

section .text.__al_big_cmp alloc exec nowrite progbits
__al_big_cmp:
    mov rcx, [rdi]
    cmp rcx, [rsi]
    jb .less
    ja .greater
.next:
    test rcx, rcx
    jz .equal
    dec rcx
    mov eax, [rdi + rcx*4 + 8]
    cmp eax, [rsi + rcx*4 + 8]
    jb .less
    ja .greater
    jmp .next
.less:
    mov eax, -1
    ret
.greater:
    mov eax, 1
    ret
.equal:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
