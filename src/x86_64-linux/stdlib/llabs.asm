; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: llabs
; header: stdlib.h
; prototype: long long llabs(long long value)
; standard: C17 7.22.6.1
; deps: labs
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:c17-integer-arithmetic
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the signed long long absolute value when representable.
; semantics: The most negative value is outside the representable result domain.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global llabs:function
extern labs:function

section .text.llabs alloc exec nowrite progbits
llabs:
    sub rsp, 8
    call labs
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
