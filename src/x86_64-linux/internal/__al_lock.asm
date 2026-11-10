; Original implementation. The argument is a pointer to a zeroed lock word.
bits 64
default rel

global __al_lock:function

section .text.__al_lock alloc exec nowrite progbits
__al_lock:
    ; Phase 1 has only the initial thread.
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
