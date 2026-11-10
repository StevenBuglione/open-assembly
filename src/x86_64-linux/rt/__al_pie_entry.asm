; Original optional process entry. Preserve the initial kernel stack.
bits 64
default rel

global __al_pie_entry:function
extern __ehdr_start:data
extern _DYNAMIC:data
extern __al_pie_relocate:function
extern __al_panic:function
extern _start:function

section .text.__al_pie_entry alloc exec nowrite progbits
__al_pie_entry:
    cld
    xor ebp, ebp
    lea rdi, [rel __ehdr_start]
    lea rsi, [rel _DYNAMIC]
    call __al_pie_relocate
    test eax, eax
    jz .start
    lea rdi, [rel relocation_error]
    mov esi, 45
    call __al_panic
    ud2
.start:
    jmp _start

section .rodata.__al_pie_entry alloc noexec nowrite progbits
relocation_error: db "open-assembly: invalid static PIE relocation", 10

section .note.GNU-stack noalloc noexec nowrite progbits
