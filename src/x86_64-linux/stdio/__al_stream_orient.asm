; Query or establish orientation while the caller owns the stream lock.
bits 64
default rel

global __al_stream_orient:function
extern __al_locale_flags:data

section .text.__al_stream_orient alloc exec nowrite progbits
__al_stream_orient:
    mov eax, [rdi + 128]
    test eax, eax
    jnz .return
    test esi, esi
    jz .return
    js .byte
    mov eax, [rel __al_locale_flags]
    and eax, 1                  ; capture C or UTF-8 for this association
    mov [rdi + 132], eax
    mov eax, 1
    jmp .publish
.byte:
    mov eax, -1
.publish:
    mov [rdi + 128], eax
.return:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
