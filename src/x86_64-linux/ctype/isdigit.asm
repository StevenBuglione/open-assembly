; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: isdigit
; header: ctype.h
; prototype: int isdigit(int c)
; standard: C17 7.4.1.5
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:ascii-c-locale
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Input is EOF (-1) or a value representable as unsigned char. Other inputs are outside the C17 contract.
; semantics: In the C locale, return 1 for ASCII digits 0 through 9. Return 0 otherwise, including EOF.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global isdigit:function

section .text.isdigit alloc exec nowrite progbits
isdigit:
    movsxd rdi, edi
    lea rcx, [rdi - 48]
    xor eax, eax
    cmp rcx, 9
    ja .done
    mov eax, 1
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
