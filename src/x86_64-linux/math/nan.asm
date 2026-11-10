; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: nan
; header: math.h
; prototype: double nan(const char *tagp)
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

global nan:function

section .text.nan alloc exec nowrite progbits
nan:
    mov rax, 0x7ff8000000000000
    movq xmm0, rax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
