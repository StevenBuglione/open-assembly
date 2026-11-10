; Declare the GNU stack note executable.
bits 64
default rel

section .text
global seed_executable_stack_note:function
seed_executable_stack_note:
    ret

section .note.GNU-stack noalloc exec nowrite progbits
