; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: div
; header: stdlib.h
; prototype: div_t div(int numerator, int denominator)
; standard: C17 7.22.6.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:c17-integer-arithmetic
; provenance: original
; narrow_args: edi:s32, esi:s32
; variadic: false
; semantics: Return the quotient rounded toward zero and remainder as two signed int members.
; semantics: The denominator must be nonzero and the quotient must be representable.
; semantics: AMD64 returns the two int members in one integer eightbyte.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global div:function

section .text.div alloc exec nowrite progbits
$div:
    movsxd rax, edi
    movsxd rcx, esi
    cqo
    idiv rcx
    mov eax, eax                  ; quotient occupies the low dword
    shl rdx, 32                   ; remainder occupies the high dword
    or rax, rdx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
