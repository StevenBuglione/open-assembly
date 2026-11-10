; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: imaxabs
; header: inttypes.h
; prototype: intmax_t imaxabs(intmax_t value)
; standard: C17 7.8.2.1
; deps: labs
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:c17-integer-arithmetic
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the signed intmax_t absolute value when representable.
; semantics: The most negative value is outside the representable result domain.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global imaxabs:function
extern labs:function

section .text.imaxabs alloc exec nowrite progbits
imaxabs:
    sub rsp, 8
    call labs
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
