; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: isblank
; header: ctype.h
; prototype: int isblank(int c)
; standard: C17 7.4.1.3
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:ascii-c-locale
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Input is EOF (-1) or a value representable as unsigned char. Other inputs are outside the C17 contract.
; semantics: In the C locale, return 1 for ASCII tab and space. Return 0 otherwise, including EOF.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global isblank:function

section .text.isblank alloc exec nowrite progbits
isblank:
    movsxd rdi, edi
    cmp rdi, 32                  ; space
    je .yes
    cmp rdi, 9                   ; horizontal tab
    je .yes
    xor eax, eax
    ret
.yes:
    mov eax, 1
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
