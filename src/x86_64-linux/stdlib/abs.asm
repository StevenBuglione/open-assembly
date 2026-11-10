; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: abs
; header: stdlib.h
; prototype: int abs(int value)
; standard: C17 7.22.6.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:lua-posix-abi, reference:c17-integer-arithmetic
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Return the absolute value of the signed integer when the result is representable.
; semantics: Preserve errno. INT_MIN is outside the C17 contract.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global abs:function

section .text.abs alloc exec nowrite progbits
$abs:
    movsxd rax, edi
    test eax, eax
    jns .done
    neg eax
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
