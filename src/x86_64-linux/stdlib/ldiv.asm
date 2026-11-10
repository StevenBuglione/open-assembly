; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: ldiv
; header: stdlib.h
; prototype: ldiv_t ldiv(long numerator, long denominator)
; standard: C17 7.22.6.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:c17-integer-arithmetic
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the quotient rounded toward zero and remainder as two signed long members.
; semantics: The denominator must be nonzero and the quotient must be representable.
; semantics: AMD64 returns quotient in RAX and remainder in RDX.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global ldiv:function

section .text.ldiv alloc exec nowrite progbits
ldiv:
    mov rax, rdi
    cqo
    idiv rsi
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
