; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: mbtowc
; header: stdlib.h
; prototype: int mbtowc(wchar_t *restrict pwc, const char *restrict s, size_t n)
; standard: C17 7.22.7.2
; deps: __errno_location
; errno: EILSEQ
; mt_safe: true
; as_safe: false
; oracles: reference:unicode-scalar, reference:mbstate-transition, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Decode a complete multibyte character. A null source resets the conversion state and returns zero.
; semantics: Return minus one and set EILSEQ on invalid input. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global mbtowc:function
extern __al_mb_legacy:function

section .text.mbtowc alloc exec nowrite progbits
mbtowc:
    mov ecx, 10
    sub rsp, 8
    call __al_mb_legacy
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
