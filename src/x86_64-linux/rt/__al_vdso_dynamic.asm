; Read one unique nonzero DT_* value from a bounded Elf64_Dyn array.
; rdi = entries, rsi = entry count, rdx = exact tag.
bits 64
default rel

global __al_vdso_dynamic:function

section .text.__al_vdso_dynamic alloc exec nowrite progbits
__al_vdso_dynamic:
    xor eax, eax
.next:
    test rsi, rsi
    jz .invalid
    mov rcx, [rdi]
    test rcx, rcx                ; DT_NULL
    jz .done
    cmp rcx, rdx
    jne .advance
    test rax, rax
    jnz .invalid
    mov rax, [rdi + 8]
    test rax, rax
    jz .invalid
.advance:
    add rdi, 16
    dec rsi
    jmp .next
.invalid:
    xor eax, eax
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
