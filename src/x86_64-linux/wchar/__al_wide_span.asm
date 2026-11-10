; Count prefix elements whose set membership matches mode edx.
bits 64
default rel

global __al_wide_span:function

section .text.__al_wide_span alloc exec nowrite progbits
__al_wide_span:
    xor eax, eax
.next:
    mov ecx, [rdi + rax*4]
    test ecx, ecx
    jz .done
    mov r8, rsi
.scan_set:
    mov r9d, [r8]
    test r9d, r9d
    jz .absent
    cmp r9d, ecx
    je .present
    add r8, 4
    jmp .scan_set
.absent:
    test edx, edx
    jnz .done
    jmp .advance
.present:
    test edx, edx
    jz .done
.advance:
    inc rax
    jmp .next
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
