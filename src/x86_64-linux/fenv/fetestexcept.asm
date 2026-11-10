; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fetestexcept
; header: fenv.h
; prototype: int fetestexcept(int excepts)
; standard: C17 7.6.2.5
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:fenv-hardware
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Return the intersection of the requested flags and the union of the x87 and SSE standard status flags.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fetestexcept:function

section .text.fetestexcept alloc exec nowrite progbits
fetestexcept:
    movsxd rdi, edi
    sub rsp, 8
    xor eax, eax
    fnstsw ax
    stmxcsr [rsp]
    or eax, [rsp]
    and eax, edi
    and eax, 61
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
