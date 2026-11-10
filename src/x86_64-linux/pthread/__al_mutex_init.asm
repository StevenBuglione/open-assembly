; Original shared mutex initialization. rdi = object, esi = private kind.
bits 64
default rel

global __al_mutex_init:function

section .text.__al_mutex_init alloc exec nowrite progbits
__al_mutex_init:
    test rdi, rdi
    jz .invalid
    cmp esi, 2
    ja .invalid
    mov dword [rdi], 0
    mov [rdi + 4], esi
    mov qword [rdi + 8], 0
    mov qword [rdi + 16], 0
    mov qword [rdi + 24], 0
    xor eax, eax
    ret
.invalid:
    mov eax, 22                   ; EINVAL
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
