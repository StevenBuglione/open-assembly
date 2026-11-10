; Return the first wide character outside the current LC_CTYPE space class.
bits 64
default rel

global __al_skip_wide_space:function
extern iswspace:function

section .text.__al_skip_wide_space alloc exec nowrite progbits
__al_skip_wide_space:
    push rbx
    mov rbx, rdi
.next:
    mov edi, [rbx]
    test edi, edi
    jz .return
    call iswspace
    test eax, eax
    jz .return
    add rbx, 4
    jmp .next
.return:
    mov rax, rbx
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
