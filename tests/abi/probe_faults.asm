; Runtime harness controls. Build one defect at a time.
bits 64
default rel

global __al_test_strlen:function

%ifdef FAIL_ABI
section .rodata
default_mxcsr: dd 0x1f80
default_x87_cw: dw 0x037f
%endif

section .text
__al_test_strlen:
    xor eax, eax
%ifdef FAIL_ABI
    xor ebx, ebx
    xor ebp, ebp
    xor r12d, r12d
    xor r13d, r13d
    xor r14d, r14d
    xor r15d, r15d
    ldmxcsr [rel default_mxcsr]
    fldcw [rel default_x87_cw]
    fld1
    std
    ret 8
%elifdef FAIL_GUARD_START
    mov dl, [rdi - 1]
    ret
%elifdef FAIL_GUARD_END
    mov dl, [rdi + 1]
    ret
%elifdef FAIL_GUARD_WRITE
    mov byte [rdi], 0
    ret
%else
    %error Choose a runtime fault control.
%endif

section .note.GNU-stack noalloc noexec nowrite progbits
