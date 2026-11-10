; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: word_math_clamp_u32
; header: word_math.h
; prototype: unsigned int word_math_clamp_u32(unsigned int value, unsigned int ceiling)
; standard: Extension ABI word_math
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:unsigned-minimum
; provenance: original
; narrow_args: edi:u32, esi:u32
; variadic: false
; semantics: Return the smaller of value and ceiling, compared as unsigned 32-bit integers.
; semantics: Do not access memory or modify errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global word_math_clamp_u32:function

section .text.word_math_clamp_u32 alloc exec nowrite progbits
word_math_clamp_u32:
    mov edi, edi
    mov esi, esi
    cmp edi, esi
    ja .ceiling
    mov eax, edi
    ret
.ceiling:
    mov eax, esi
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
