; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wcslen
; header: wchar.h
; prototype: size_t wcslen(const wchar_t *s)
; standard: C17 7.29.4.6.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:wide-object-bounds, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the number of wide elements before the terminating null.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wcslen:function

section .text.wcslen alloc exec nowrite progbits
wcslen:
    xor eax, eax
.next:
    cmp dword [rdi + rax*4], 0
    je .done
    inc rax
    jmp .next
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
