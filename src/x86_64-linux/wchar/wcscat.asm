; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wcscat
; header: wchar.h
; prototype: wchar_t *wcscat(wchar_t *restrict dst, const wchar_t *restrict src)
; standard: C17 7.29.4.3.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:wide-object-bounds, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Append a wide string and its terminating null.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wcscat:function

section .text.wcscat alloc exec nowrite progbits
wcscat:
    mov rax, rdi
.seek:
    cmp dword [rdi], 0
    je .copy
    add rdi, 4
    jmp .seek
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
