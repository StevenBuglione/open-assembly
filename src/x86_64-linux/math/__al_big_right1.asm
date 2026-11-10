; Original in-place right shift by one. rdi = value.
bits 64
default rel

global __al_big_right1:function

section .text.__al_big_right1 alloc exec nowrite progbits
__al_big_right1:
    mov rcx, [rdi]
    test rcx, rcx
    jz .done
    xor edx, edx                 ; carry from the next higher limb
.next:
    dec rcx
    mov eax, [rdi + rcx*4 + 8]
    mov r8d, eax
    shr eax, 1
    or eax, edx
    mov [rdi + rcx*4 + 8], eax
    shl r8d, 31
    mov edx, r8d
    test rcx, rcx
    jnz .next
    mov rcx, [rdi]
    cmp dword [rdi + rcx*4 + 4], 0
    jne .done
    dec qword [rdi]
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
