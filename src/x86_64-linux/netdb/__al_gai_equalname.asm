; Compare local node names ignoring ASCII case and one final dot.
bits 64
default rel

global __al_gai_equalname:function

section .text.__al_gai_equalname alloc exec nowrite progbits
__al_gai_equalname:
.next:
    movzx eax, byte [rdi]
    movzx ecx, byte [rsi]
    cmp eax, 46
    jne .fold_left
    cmp byte [rdi + 1], 0
    jne .fold_left
    xor eax, eax
.fold_left:
    lea edx, [rax - 65]
    cmp edx, 25
    ja .dot_right
    add eax, 32
.dot_right:
    cmp ecx, 46
    jne .fold_right
    cmp byte [rsi + 1], 0
    jne .fold_right
    xor ecx, ecx
.fold_right:
    lea edx, [rcx - 65]
    cmp edx, 25
    ja .compare
    add ecx, 32
.compare:
    cmp eax, ecx
    jne .different
    test eax, eax
    jz .equal
    inc rdi
    inc rsi
    jmp .next
.equal:
    mov eax, 1
    ret
.different:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
