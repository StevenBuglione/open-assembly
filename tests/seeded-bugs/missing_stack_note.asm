; Omit the ELF note that marks the stack non-executable.
bits 64
default rel

section .text
global seed_missing_stack_note:function
seed_missing_stack_note:
    ret
