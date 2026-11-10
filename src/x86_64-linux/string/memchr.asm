; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: memchr
; header: string.h
; prototype: void *memchr(const void *s, int c, size_t n)
; standard: C17 7.24.5.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:byte-ranges
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Search at most n bytes for c converted to unsigned char and return the address of the first match or NULL.
; semantics: With zero length, access no bytes and return NULL.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global memchr:function

section .text.memchr alloc exec nowrite progbits
memchr:
    movsxd rsi, esi
    test rdx, rdx
    jz .absent
.next:
    cmp byte [rdi], sil
    je .found
    inc rdi
    dec rdx
    jnz .next
.absent:
    xor eax, eax
    ret
.found:
    mov rax, rdi
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
