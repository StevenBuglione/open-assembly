; Publish errno in esi if nonzero and raise the requested fenv mask in edi.
bits 64
default rel

global __al_math_effects:function
extern __errno_location:function
extern feraiseexcept:function

section .text.__al_math_effects alloc exec nowrite progbits
__al_math_effects:
    push rbx
    push r12
    sub rsp, 8
    mov ebx, edi
    mov r12d, esi
    test esi, esi
    jz .exceptions
    call __errno_location
    mov [rax], r12d
.exceptions:
    test ebx, ebx
    jz .done
    mov edi, ebx
    call feraiseexcept
.done:
    add rsp, 8
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
