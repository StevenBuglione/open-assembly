; Invoke a directory-error callback and return zero to continue or GLOB_ABORTED.
; RDI path, ESI errno, RDX callback or null, ECX glob flags.
bits 64
default rel

global __al_glob_error:function

section .text.__al_glob_error alloc exec nowrite progbits
__al_glob_error:
    push rbx
    mov ebx, ecx
    mov rax, rdx
    test rax, rax
    jz .flags
    call rax
    test eax, eax
    jnz .abort
.flags:
    test ebx, 1                 ; GLOB_ERR
    jnz .abort
    xor eax, eax
    jmp .return
.abort:
    mov eax, 2                  ; GLOB_ABORTED
.return:
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
