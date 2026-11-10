; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wcsncat
; header: wchar.h
; prototype: wchar_t *wcsncat(wchar_t *restrict dst, const wchar_t *restrict src, size_t n)
; standard: C17 7.29.4.3.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:wide-object-bounds, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Append at most n non-null wide elements and write one terminating null.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wcsncat:function

section .text.wcsncat alloc exec nowrite progbits
wcsncat:
    mov rax, rdi
.seek:
    cmp dword [rdi], 0
    je .copy
    add rdi, 4
    jmp .seek
.copy:
    test rdx, rdx
    jz .terminate
    mov ecx, [rsi]
    test ecx, ecx
    jz .terminate
    mov [rdi], ecx
    add rsi, 4
    add rdi, 4
    dec rdx
    jmp .copy
.terminate:
    mov dword [rdi], 0
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
