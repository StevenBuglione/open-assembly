; Test-only probe of the x86-64 System V ABI for a scalar-return strlen.
bits 64
default rel

global al_check_strlen_abi:function
extern __al_test_strlen

%define rsp_changed     (1 << 0)
%define df_set          (1 << 1)
%define rbx_changed     (1 << 2)
%define rbp_changed     (1 << 3)
%define r12_changed     (1 << 4)
%define r13_changed     (1 << 5)
%define r14_changed     (1 << 6)
%define r15_changed     (1 << 7)
%define mxcsr_changed   (1 << 8)
%define x87_cw_changed  (1 << 9)
%define x87_stack_dirty (1 << 10)

%define rbx_sentinel 0x0d6acb5e804717f3
%define rbp_sentinel 0xc43132ec58216dbf
%define r12_sentinel 0x379ef5d963f0d2a4
%define r13_sentinel 0x6b2c8f059ad741e6
%define r14_sentinel 0xf197b0425c380aed
%define r15_sentinel 0x843f61ba09d2ce57

%define caller_fp       0
%define candidate_fp    512
%define result_pointer  1024
%define frame_size      1048
%define fxsave_x87_cw   0
%define fxsave_x87_tag  4
%define fxsave_mxcsr    24
%define mxcsr_control   0xffc0

section .bss
align 8
; This single-threaded test recovers from a candidate returning at the wrong RSP.
expected_rsp: resq 1

section .rodata
align 4
probe_mxcsr: dd 0xdf80
probe_x87_cw: dw 0x0a7f

section .text

%macro check_register 3
    mov rdx, %2
    cmp %1, rdx
    je %%preserved
    or ecx, %3
%%preserved:
%endmacro

; unsigned al_check_strlen_abi(const char *s, size_t *result);
; Return a bit mask, preserve the caller's state, and report the tested result.
al_check_strlen_abi:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    sub rsp, frame_size

    mov [rsp + result_pointer], rsi
    mov [rel expected_rsp], rsp
    fxsave64 [rsp + caller_fp]
    fninit
    fldcw [rel probe_x87_cw]
    ldmxcsr [rel probe_mxcsr]
    cld

    mov rbx, rbx_sentinel
    mov rbp, rbp_sentinel
    mov r12, r12_sentinel
    mov r13, r13_sentinel
    mov r14, r14_sentinel
    mov r15, r15_sentinel
    call __al_test_strlen

    xor ecx, ecx
    mov rdx, [rel expected_rsp]
    cmp rsp, rdx
    je .rsp_ok
    or ecx, rsp_changed
.rsp_ok:
    mov rsp, rdx
    mov rdx, [rsp + result_pointer]
    mov [rdx], rax

    pushfq
    pop rdx
    test edx, 1 << 10
    jz .df_ok
    or ecx, df_set
.df_ok:
    cld

    check_register rbx, rbx_sentinel, rbx_changed
    check_register rbp, rbp_sentinel, rbp_changed
    check_register r12, r12_sentinel, r12_changed
    check_register r13, r13_sentinel, r13_changed
    check_register r14, r14_sentinel, r14_changed
    check_register r15, r15_sentinel, r15_changed

    fxsave64 [rsp + candidate_fp]
    mov edx, [rsp + candidate_fp + fxsave_mxcsr]
    and edx, mxcsr_control
    cmp edx, [rel probe_mxcsr]
    je .mxcsr_ok
    or ecx, mxcsr_changed
.mxcsr_ok:
    mov dx, [rsp + candidate_fp + fxsave_x87_cw]
    cmp dx, [rel probe_x87_cw]
    je .x87_cw_ok
    or ecx, x87_cw_changed
.x87_cw_ok:
    cmp byte [rsp + candidate_fp + fxsave_x87_tag], 0
    je .x87_stack_ok
    or ecx, x87_stack_dirty
.x87_stack_ok:
    fxrstor64 [rsp + caller_fp]
    mov eax, ecx
    add rsp, frame_size
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
