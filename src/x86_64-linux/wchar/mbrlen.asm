; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: mbrlen
; header: wchar.h
; prototype: size_t mbrlen(const char *restrict s, size_t n, mbstate_t *restrict ps)
; standard: C17 7.29.6.3.1
; deps: __errno_location
; errno: EILSEQ
; mt_safe: true
; as_safe: false
; oracles: reference:unicode-scalar, reference:mbstate-transition, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Count the bytes completing one multibyte character in the current LC_CTYPE, with a separate default conversion state.
; semantics: Clear the affected state on an encoding error. Preserve errno for successful or incomplete conversions.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global mbrlen:function
extern __al_mbr_scalar:function

section .text.mbrlen alloc exec nowrite progbits
mbrlen:
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    xor edi, edi
    mov r8d, 1
    sub rsp, 8
    call __al_mbr_scalar
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
