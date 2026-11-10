; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: tolower
; header: ctype.h
; prototype: int tolower(int c)
; standard: C17 7.4.2.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:ascii-c-locale
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Input is EOF (-1) or a value representable as unsigned char. Other inputs are outside the C17 contract.
; semantics: Map ASCII A through Z to the matching lowercase letter. Return all other inputs unchanged.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global tolower:function

section .text.tolower alloc exec nowrite progbits
tolower:
    movsxd rax, edi
    lea rcx, [rax - 65]
    cmp rcx, 25
    ja .done
    add eax, 32
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
