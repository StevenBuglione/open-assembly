; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: feraiseexcept
; header: fenv.h
; prototype: int feraiseexcept(int excepts)
; standard: C17 7.6.2.3
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:fenv-hardware
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Raise the requested supported floating exceptions. Return zero if execution continues.
; semantics: Raising overflow or underflow can additionally raise inexact. Preserve rounding modes and exception masks.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global feraiseexcept:function

section .text.feraiseexcept alloc exec nowrite progbits
feraiseexcept:
    movsxd rdi, edi
    test edi, 1
    jz .divide
    pxor xmm0, xmm0
    divsd xmm0, xmm0             ; invalid operation
.divide:
    test edi, 4
    jz .overflow
    movsd xmm0, [rel one]
    pxor xmm1, xmm1
    divsd xmm0, xmm1
.overflow:
    test edi, 8
    jz .underflow
    movsd xmm0, [rel largest]
    movsd xmm1, [rel two]
    mulsd xmm0, xmm1
.underflow:
    test edi, 16
    jz .inexact
    movsd xmm0, [rel smallest]
    mulsd xmm0, xmm0
.inexact:
    test edi, 32
    jz .done
    movsd xmm0, [rel one]
    movsd xmm1, [rel three]
    divsd xmm0, xmm1
.done:
    xor eax, eax
    ret

section .rodata.feraiseexcept alloc noexec nowrite progbits align=8
one:
    dq 0x3ff0000000000000
two:
    dq 0x4000000000000000
three:
    dq 0x4008000000000000
largest:
    dq 0x7fefffffffffffff
smallest:
    dq 0x0010000000000000

section .note.GNU-stack noalloc noexec nowrite progbits
