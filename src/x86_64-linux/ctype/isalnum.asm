; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: isalnum
; header: ctype.h
; prototype: int isalnum(int c)
; standard: C17 7.4.1.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:ascii-c-locale
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Input is EOF (-1) or a value representable as unsigned char. Other inputs are outside the C17 contract.
; semantics: In the C locale, return 1 for ASCII letters A through Z or a through z, and digits 0 through 9. Return 0 otherwise, including EOF.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global isalnum:function

section .text.isalnum alloc exec nowrite progbits
isalnum:
    movsxd rdi, edi
    lea rcx, [rdi - 48]           ; ASCII digit
    cmp rcx, 9
    jbe .yes
    or rdi, 32                   ; fold ASCII letter case
    sub rdi, 97
    cmp rdi, 25
    jbe .yes
    xor eax, eax
    ret
.yes:
    mov eax, 1
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
