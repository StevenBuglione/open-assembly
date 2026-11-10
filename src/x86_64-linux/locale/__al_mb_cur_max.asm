; Return the maximum byte width selected by LC_CTYPE.
bits 64
default rel

global __al_mb_cur_max:function
extern __al_locale_flags:data

section .text.__al_mb_cur_max alloc exec nowrite progbits
__al_mb_cur_max:
    mov eax, [rel __al_locale_flags]
    and eax, 1
    lea rax, [rax + rax*2 + 1]
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
