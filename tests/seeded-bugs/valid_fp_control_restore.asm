; Accept caller floating-point control state restored from saved stack slots.
bits 64
default rel

section .text
global test_valid_fp_control_restore:function
test_valid_fp_control_restore:
    sub rsp, 16
    stmxcsr [rsp]
    fnstcw [rsp + 4]
    ldmxcsr [rdi]
    fldcw [rsi]
    ldmxcsr [rsp]
    fldcw [rsp + 4]
    add rsp, 16
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
