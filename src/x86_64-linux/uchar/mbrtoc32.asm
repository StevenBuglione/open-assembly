; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: mbrtoc32
; header: uchar.h
; prototype: size_t mbrtoc32(char32_t *restrict pc32, const char *restrict s, size_t n, mbstate_t *restrict ps)
; standard: C17 7.28.1.3
; deps: __errno_location
; errno: EILSEQ
; mt_safe: true
; as_safe: false
; oracles: reference:unicode-scalar, reference:mbstate-transition, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Decode one scalar value into UTF-32 using the restartable multibyte state and current LC_CTYPE.
; semantics: Clear the affected state on an encoding error. Preserve errno for successful or incomplete conversions.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global mbrtoc32:function
extern __al_mbr_scalar:function

section .text.mbrtoc32 alloc exec nowrite progbits
mbrtoc32:
    mov r8d, 4
    sub rsp, 8
    call __al_mbr_scalar
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
