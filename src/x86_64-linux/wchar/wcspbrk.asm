; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wcspbrk
; header: wchar.h
; prototype: wchar_t *wcspbrk(const wchar_t *s, const wchar_t *accept)
; standard: C17 7.29.4.5.3
; deps: wcscspn
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:wide-object-bounds, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Find the first wide element contained in the acceptance set.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wcspbrk:function
extern wcscspn:function

section .text.wcspbrk alloc exec nowrite progbits
wcspbrk:
    push rbx
    mov rbx, rdi
    call wcscspn
    lea rax, [rbx + rax*4]
    cmp dword [rax], 0
    jne .done
    xor eax, eax
.done:
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
