; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: iscntrl
; header: ctype.h
; prototype: int iscntrl(int c)
; standard: C17 7.4.1.4
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:ascii-c-locale
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Input is EOF (-1) or a value representable as unsigned char. Other inputs are outside the C17 contract.
; semantics: In the C locale, return 1 for ASCII control bytes 0 through 31 and 127. Return 0 otherwise, including EOF.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global iscntrl:function

section .text.iscntrl alloc exec nowrite progbits
iscntrl:
    movsxd rdi, edi
    cmp rdi, 31                  ; ASCII C0 controls
    jbe .yes
    cmp rdi, 127                 ; DEL
    je .yes
    xor eax, eax
    ret
.yes:
    mov eax, 1
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
