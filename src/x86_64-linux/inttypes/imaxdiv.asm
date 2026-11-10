; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: imaxdiv
; header: inttypes.h
; prototype: imaxdiv_t imaxdiv(intmax_t numerator, intmax_t denominator)
; standard: C17 7.8.2.2
; deps: ldiv
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:c17-integer-arithmetic
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the quotient rounded toward zero and remainder as two signed intmax_t members.
; semantics: The denominator must be nonzero and the quotient must be representable.
; semantics: AMD64 returns quotient in RAX and remainder in RDX.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global imaxdiv:function
extern ldiv:function

section .text.imaxdiv alloc exec nowrite progbits
imaxdiv:
    sub rsp, 8
    call ldiv
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
