; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wcscpy
; header: wchar.h
; prototype: wchar_t *wcscpy(wchar_t *restrict dst, const wchar_t *restrict src)
; standard: C17 7.29.4.2.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:wide-object-bounds, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Copy the wide string and its terminating null.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wcscpy:function

section .text.wcscpy alloc exec nowrite progbits
wcscpy:
    mov rax, rdi
.copy:
    mov ecx, [rsi]
    mov [rdi], ecx
    test ecx, ecx
    jz .done
    add rsi, 4
    add rdi, 4
    jmp .copy
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
