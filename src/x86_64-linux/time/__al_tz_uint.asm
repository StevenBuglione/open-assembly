; Original bounded decimal field. Inputs: cursor, maximum. Outputs: next
; cursor and value, or null if there was no digit or the value is too large.
bits 64
default rel

global __al_tz_uint:function

section .text.__al_tz_uint alloc exec nowrite progbits
__al_tz_uint:
    mov rax, rdi
    xor edx, edx
.next:
    movzx ecx, byte [rax]
    sub ecx, 48
    cmp ecx, 9
    ja .end
    imul edx, 10
    add edx, ecx
    cmp edx, esi
    ja .invalid
    inc rax
    jmp .next
.end:
    cmp rax, rdi
    jne .done
.invalid:
    xor eax, eax
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
