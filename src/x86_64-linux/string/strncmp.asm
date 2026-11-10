; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strncmp
; header: string.h
; prototype: int strncmp(const char *a, const char *b, size_t n)
; standard: C17 7.24.4.4
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:byte-strings
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compare up to n bytes as unsigned char, stopping at the first difference or NUL.
; semantics: Return the sign of the first difference or zero. With zero length, access neither string.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strncmp:function

section .text.strncmp alloc exec nowrite progbits
strncmp:
    xor eax, eax
    test rdx, rdx
    jz .done
.next:
    movzx eax, byte [rdi]
    movzx ecx, byte [rsi]
    cmp eax, ecx
    jne .difference
    test eax, eax
    jz .done
    inc rdi
    inc rsi
    dec rdx
    jnz .next
    xor eax, eax
    ret
.difference:
    sub eax, ecx
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
