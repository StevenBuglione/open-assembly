; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: isgraph
; header: ctype.h
; prototype: int isgraph(int c)
; standard: C17 7.4.1.6
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:ascii-c-locale
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Input is EOF (-1) or a value representable as unsigned char. Other inputs are outside the C17 contract.
; semantics: In the C locale, return 1 for ASCII bytes 33 through 126. Return 0 otherwise, including EOF.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global isgraph:function

section .text.isgraph alloc exec nowrite progbits
isgraph:
    movsxd rdi, edi
    lea rcx, [rdi - 33]
    xor eax, eax
    cmp rcx, 93
    ja .done
    mov eax, 1
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
