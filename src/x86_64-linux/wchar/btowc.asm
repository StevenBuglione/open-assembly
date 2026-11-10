; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: btowc
; header: wchar.h
; prototype: wint_t btowc(int c)
; standard: C17 7.29.6.1.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:unicode-scalar, reference:mbstate-transition, diff:glibc
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Return the corresponding wide character for a single ASCII byte. Return WEOF for EOF or a byte that is invalid as a complete multibyte character.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global btowc:function

section .text.btowc alloc exec nowrite progbits
btowc:
    movsxd rax, edi
    cmp rax, 127
    jbe .return
    mov eax, -1
.return:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
