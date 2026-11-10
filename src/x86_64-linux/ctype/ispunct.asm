; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: ispunct
; header: ctype.h
; prototype: int ispunct(int c)
; standard: C17 7.4.1.9
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:ascii-c-locale
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Input is EOF (-1) or a value representable as unsigned char. Other inputs are outside the C17 contract.
; semantics: In the C locale, return 1 for ASCII graphical bytes other than letters and digits. Return 0 otherwise, including EOF.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global ispunct:function

section .text.ispunct alloc exec nowrite progbits
ispunct:
    movsxd rdi, edi
    lea rcx, [rdi - 33]           ; graphical range
    cmp rcx, 93
    ja .no
    lea rcx, [rdi - 48]           ; exclude digits
    cmp rcx, 9
    jbe .no
    or rdi, 32                   ; exclude letters in either case
    sub rdi, 97
    cmp rdi, 25
    jbe .no
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
