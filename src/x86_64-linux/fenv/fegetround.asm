; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fegetround
; header: fenv.h
; prototype: int fegetround(void)
; standard: C17 7.6.3.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:fenv-hardware
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the current rounding-mode constant.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fegetround:function

section .text.fegetround alloc exec nowrite progbits
fegetround:
    sub rsp, 8
    stmxcsr [rsp]
    mov eax, [rsp]
    shr eax, 3
    and eax, 3072
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
