; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wcscmp
; header: wchar.h
; prototype: int wcscmp(const wchar_t *a, const wchar_t *b)
; standard: C17 7.29.4.4.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:wide-object-bounds, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compare two wide strings by their first unequal signed wchar_t values.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wcscmp:function

section .text.wcscmp alloc exec nowrite progbits
wcscmp:
.next:
    mov ecx, [rdi]
    cmp ecx, [rsi]
    jl .less
    jg .greater
    test ecx, ecx
    jz .equal
    add rdi, 4
    add rsi, 4
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
