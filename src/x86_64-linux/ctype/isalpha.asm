; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: isalpha
; header: ctype.h
; prototype: int isalpha(int c)
; standard: C17 7.4.1.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:ascii-c-locale
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Input is EOF (-1) or a value representable as unsigned char. Other inputs are outside the C17 contract.
; semantics: In the C locale, return 1 for ASCII letters A through Z or a through z. Return 0 otherwise, including EOF.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global isalpha:function

section .text.isalpha alloc exec nowrite progbits
isalpha:
    movsxd rdi, edi
    or rdi, 32                   ; fold ASCII letter case
    lea rcx, [rdi - 97]
    xor eax, eax
    cmp rcx, 25
    ja .done
    mov eax, 1
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
