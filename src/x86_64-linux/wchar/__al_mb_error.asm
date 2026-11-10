; Reset the conversion state at rdi and return a TLS encoding error.
bits 64
default rel

global __al_mb_error:function
extern __errno_location:function

section .text.__al_mb_error alloc exec nowrite progbits
__al_mb_error:
    mov qword [rdi], 0
    sub rsp, 8
    call __errno_location
    mov dword [rax], 84          ; EILSEQ
    mov rax, -1
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
