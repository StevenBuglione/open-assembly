; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wcsncmp
; header: wchar.h
; prototype: int wcsncmp(const wchar_t *a, const wchar_t *b, size_t n)
; standard: C17 7.29.4.4.3
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:wide-object-bounds, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compare at most n wide elements, stopping at the terminating null.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wcsncmp:function

section .text.wcsncmp alloc exec nowrite progbits
wcsncmp:
.next:
    test rdx, rdx
    jz .equal
    mov ecx, [rdi]
    cmp ecx, [rsi]
    jl .less
    jg .greater
    test ecx, ecx
    jz .equal
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
