; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: memset
; header: string.h
; prototype: void *memset(void *s, int c, size_t n)
; standard: C17 7.24.6.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:byte-ranges
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Store c converted to unsigned char in exactly n bytes and return s.
; semantics: With zero length, perform no access.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global memset:function

section .text.memset alloc exec nowrite progbits
memset:
    mov rax, rdi
    movsxd rsi, esi
    test rdx, rdx
    jz .done
.next:
    mov [rdi], sil
    inc rdi
    dec rdx
    jnz .next
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
