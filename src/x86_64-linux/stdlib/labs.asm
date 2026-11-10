; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: labs
; header: stdlib.h
; prototype: long labs(long value)
; standard: C17 7.22.6.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:c17-integer-arithmetic
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the signed long absolute value when representable.
; semantics: The most negative value is outside the representable result domain.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global labs:function

section .text.labs alloc exec nowrite progbits
labs:
    mov rax, rdi
    test rax, rax
    jns .done
    neg rax
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
