; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wmemchr
; header: wchar.h
; prototype: wchar_t *wmemchr(const wchar_t *s, wchar_t c, size_t n)
; standard: C17 7.29.4.5.8
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:wide-object-bounds, diff:glibc, diff:musl
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Find c within the first n wide elements, including zero-valued elements.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wmemchr:function

section .text.wmemchr alloc exec nowrite progbits
wmemchr:
    movsxd rsi, esi
    test rdx, rdx
    jz .miss
.next:
    cmp [rdi], esi
    je .match
    add rdi, 4
    dec rdx
    jnz .next
.miss:
    xor eax, eax
    ret
.match:
    mov rax, rdi
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
