; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: memcmp
; header: string.h
; prototype: int memcmp(const void *a, const void *b, size_t n)
; standard: C17 7.24.4.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:byte-ranges
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compare up to n bytes as unsigned char, using the sign of the first difference.
; semantics: Return zero for equal ranges. With zero length, access neither region and return zero.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global memcmp:function

section .text.memcmp alloc exec nowrite progbits
memcmp:
    test rdx, rdx
    jz .equal
.next:
    movzx eax, byte [rdi]
    movzx ecx, byte [rsi]
    sub eax, ecx
    jnz .done
    inc rdi
    inc rsi
    dec rdx
    jnz .next
.equal:
    xor eax, eax
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
