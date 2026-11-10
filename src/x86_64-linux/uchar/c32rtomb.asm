; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: c32rtomb
; header: uchar.h
; prototype: size_t c32rtomb(char *restrict s, char32_t c32, mbstate_t *restrict ps)
; standard: C17 7.28.1.4
; deps: __errno_location
; errno: EILSEQ
; mt_safe: true
; as_safe: false
; oracles: reference:unicode-scalar, reference:mbstate-transition, diff:glibc
; provenance: original
; narrow_args: esi:u32
; variadic: false
; semantics: Encode a Unicode scalar value in the current LC_CTYPE using the restartable multibyte state.
; semantics: Clear the affected state on an encoding error. Preserve errno for successful or incomplete conversions.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global c32rtomb:function
extern __al_wcr_scalar:function

section .text.c32rtomb alloc exec nowrite progbits
c32rtomb:
    mov esi, esi
    mov ecx, 6
    sub rsp, 8
    call __al_wcr_scalar
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
