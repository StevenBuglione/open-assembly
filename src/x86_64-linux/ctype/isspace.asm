; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: isspace
; header: ctype.h
; prototype: int isspace(int c)
; standard: C17 7.4.1.10
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:ascii-c-locale
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Input is EOF (-1) or a value representable as unsigned char. Other inputs are outside the C17 contract.
; semantics: In the C locale, return 1 for ASCII bytes 9 through 13 and space. Return 0 otherwise, including EOF.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global isspace:function

section .text.isspace alloc exec nowrite progbits
isspace:
    movsxd rdi, edi
    cmp rdi, 32                  ; space
    je .yes
    sub rdi, 9                   ; HT, LF, VT, FF, CR
    cmp rdi, 4
    jbe .yes
    xor eax, eax
    ret
.yes:
    mov eax, 1
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
