; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wcrtomb
; header: wchar.h
; prototype: size_t wcrtomb(char *restrict s, wchar_t wc, mbstate_t *restrict ps)
; standard: C17 7.29.6.3.3
; deps: __errno_location
; errno: EILSEQ
; mt_safe: true
; as_safe: false
; oracles: reference:unicode-scalar, reference:mbstate-transition, diff:glibc
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Encode a Unicode scalar value representable in the current LC_CTYPE. Return the stored byte count or (size_t)-1 for an encoding error.
; semantics: Clear the affected state on an encoding error. Preserve errno for successful or incomplete conversions.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wcrtomb:function
extern __al_wcr_scalar:function

section .text.wcrtomb alloc exec nowrite progbits
wcrtomb:
    movsxd rsi, esi
    mov ecx, 2
    sub rsp, 8
    call __al_wcr_scalar
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
