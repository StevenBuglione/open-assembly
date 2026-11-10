; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: mbrtowc
; header: wchar.h
; prototype: size_t mbrtowc(wchar_t *restrict pwc, const char *restrict s, size_t n, mbstate_t *restrict ps)
; standard: C17 7.29.6.3.2
; deps: __errno_location
; errno: EILSEQ
; mt_safe: true
; as_safe: false
; oracles: reference:unicode-scalar, reference:mbstate-transition, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Decode one multibyte character in the current LC_CTYPE. Return current-call byte count, zero for null, (size_t)-2 for incomplete input or (size_t)-1 for an encoding error.
; semantics: Clear the affected state on an encoding error. Preserve errno for successful or incomplete conversions.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global mbrtowc:function
extern __al_mbr_scalar:function

section .text.mbrtowc alloc exec nowrite progbits
mbrtowc:
    xor r8d, r8d
    sub rsp, 8
    call __al_mbr_scalar
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
