; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fesetexceptflag
; header: fenv.h
; prototype: int fesetexceptflag(const fexcept_t *flagp, int excepts)
; standard: C17 7.6.2.4
; deps: feclearexcept
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:fenv-hardware
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Restore the requested saved status flags without raising exceptions.
; semantics: Preserve unselected flags and control state. Return zero.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fesetexceptflag:function
extern feclearexcept:function

section .text.fesetexceptflag alloc exec nowrite progbits
fesetexceptflag:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8
    movsxd rsi, esi
    movzx ebx, word [rdi]
    and ebx, esi
    mov rdi, rsi
    call feclearexcept
    stmxcsr [rsp]
    test ebx, 1
    jz .skip_invalid
    or dword [rsp], 1
.skip_invalid:
    test ebx, 4
    jz .skip_divide
    or dword [rsp], 4
.skip_divide:
    test ebx, 8
    jz .skip_overflow
    or dword [rsp], 8
.skip_overflow:
    test ebx, 16
    jz .skip_underflow
    or dword [rsp], 16
.skip_underflow:
    test ebx, 32
    jz .skip_inexact
    or dword [rsp], 32
.skip_inexact:
    ldmxcsr [rsp]
    xor eax, eax
    add rsp, 8
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
