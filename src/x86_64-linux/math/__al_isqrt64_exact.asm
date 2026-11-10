; Return the positive integer square root of rdi if exact, else zero.
bits 64
default rel

global __al_isqrt64_exact:function

section .text.__al_isqrt64_exact alloc exec nowrite progbits
__al_isqrt64_exact:
    xor r9d, r9d
    mov r8d, 0x80000000
.bit:
    lea r10, [r9 + r8]
    mov rax, r10
    imul rax, rax
    cmp rax, rdi
    ja .next
    mov r9, r10
.next:
    shr r8, 1
    jnz .bit
    mov rax, r9
    imul rax, rax
    cmp rax, rdi
    jne .inexact
    mov rax, r9
    ret
.inexact:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
