; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: toupper
; header: ctype.h
; prototype: int toupper(int c)
; standard: C17 7.4.2.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:ascii-c-locale
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Input is EOF (-1) or a value representable as unsigned char. Other inputs are outside the C17 contract.
; semantics: Map ASCII a through z to the matching uppercase letter. Return all other inputs unchanged.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global toupper:function

section .text.toupper alloc exec nowrite progbits
toupper:
    movsxd rax, edi
    lea rcx, [rax - 97]
    cmp rcx, 25
    ja .done
    sub eax, 32
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
