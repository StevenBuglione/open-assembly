; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wmemset
; header: wchar.h
; prototype: wchar_t *wmemset(wchar_t *s, wchar_t c, size_t n)
; standard: C17 7.29.4.6.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:wide-object-bounds, diff:glibc, diff:musl
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Write c into exactly the first n wide elements.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wmemset:function

section .text.wmemset alloc exec nowrite progbits
wmemset:
    movsxd rsi, esi
    mov rax, rdi
    test rdx, rdx
    jz .done
.next:
    mov [rdi], esi
    add rdi, 4
    dec rdx
    jnz .next
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
