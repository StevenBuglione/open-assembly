; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: nanf
; header: math.h
; prototype: float nanf(const char *tagp)
; standard: C17 7.12.11.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:mpfr, reference:ieee-bits, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the canonical positive quiet NaN. The payload tag is ignored.
; semantics: Preserve errno and the floating exception flags.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global nanf:function

section .text.nanf alloc exec nowrite progbits
nanf:
    mov eax, 0x7fc00000
    movd xmm0, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
