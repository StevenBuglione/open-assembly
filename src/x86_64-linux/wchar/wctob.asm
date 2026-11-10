; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wctob
; header: wchar.h
; prototype: int wctob(wint_t c)
; standard: C17 7.29.6.1.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:unicode-scalar, reference:mbstate-transition, diff:glibc
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Return the corresponding single byte for an ASCII wide character. Return EOF for WEOF or a character with no single-byte representation.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wctob:function

section .text.wctob alloc exec nowrite progbits
wctob:
    mov eax, edi
    cmp rax, 127
    jbe .return
    mov eax, -1
.return:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
