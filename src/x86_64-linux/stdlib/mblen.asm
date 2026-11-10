; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: mblen
; header: stdlib.h
; prototype: int mblen(const char *s, size_t n)
; standard: C17 7.22.7.1
; deps: __errno_location
; errno: EILSEQ
; mt_safe: true
; as_safe: false
; oracles: reference:unicode-scalar, reference:mbstate-transition, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the byte length of a complete non-null multibyte character or zero for a null byte or a null source reset.
; semantics: Return minus one and set EILSEQ on invalid input. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global mblen:function
extern __al_mb_legacy:function

section .text.mblen alloc exec nowrite progbits
mblen:
    mov rdx, rsi
    mov rsi, rdi
    xor edi, edi
    mov ecx, 9
    sub rsp, 8
    call __al_mb_legacy
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
