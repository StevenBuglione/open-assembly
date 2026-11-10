; Original implementation. The argument is the lock word passed to __al_lock.
bits 64
default rel

global __al_unlock:function

section .text.__al_unlock alloc exec nowrite progbits
__al_unlock:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
