; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: lldiv
; header: stdlib.h
; prototype: lldiv_t lldiv(long long numerator, long long denominator)
; standard: C17 7.22.6.2
; deps: ldiv
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:c17-integer-arithmetic
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the quotient rounded toward zero and remainder as two signed long long members.
; semantics: The denominator must be nonzero and the quotient must be representable.
; semantics: AMD64 returns quotient in RAX and remainder in RDX.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global lldiv:function
extern ldiv:function

section .text.lldiv alloc exec nowrite progbits
lldiv:
    sub rsp, 8
    call ldiv
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
