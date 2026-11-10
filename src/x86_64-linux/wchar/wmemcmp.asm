; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wmemcmp
; header: wchar.h
; prototype: int wmemcmp(const wchar_t *a, const wchar_t *b, size_t n)
; standard: C17 7.29.4.4.5
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:wide-object-bounds, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compare exactly n wide elements by their signed values.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wmemcmp:function

section .text.wmemcmp alloc exec nowrite progbits
wmemcmp:
.next:
    test rdx, rdx
    jz .equal
    mov ecx, [rdi]
    cmp ecx, [rsi]
    jl .less
    jg .greater
    add rdi, 4
    add rsi, 4
    dec rdx
    jmp .next
.equal:
    xor eax, eax
    ret
.less:
    mov eax, -1
    ret
.greater:
    mov eax, 1
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
