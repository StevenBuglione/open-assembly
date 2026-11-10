; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wcsrchr
; header: wchar.h
; prototype: wchar_t *wcsrchr(const wchar_t *s, wchar_t c)
; standard: C17 7.29.4.5.4
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:wide-object-bounds, diff:glibc, diff:musl
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Find the last occurrence of c, including the terminating null.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wcsrchr:function

section .text.wcsrchr alloc exec nowrite progbits
wcsrchr:
    movsxd rsi, esi
    xor eax, eax
.next:
    mov ecx, [rdi]
    cmp ecx, esi
    jne .check_null
    mov rax, rdi
.check_null:
    test ecx, ecx
    jz .done
    add rdi, 4
    jmp .next
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
