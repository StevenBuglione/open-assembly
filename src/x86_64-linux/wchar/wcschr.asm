; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wcschr
; header: wchar.h
; prototype: wchar_t *wcschr(const wchar_t *s, wchar_t c)
; standard: C17 7.29.4.5.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:wide-object-bounds, diff:glibc, diff:musl
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Find the first occurrence of c, including the terminating null.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wcschr:function

section .text.wcschr alloc exec nowrite progbits
wcschr:
    movsxd rsi, esi
.next:
    mov eax, [rdi]
    cmp eax, esi
    je .match
    test eax, eax
    jz .miss
    add rdi, 4
    jmp .next
.match:
    mov rax, rdi
    ret
.miss:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
