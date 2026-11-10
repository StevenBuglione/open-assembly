; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: mbsinit
; header: wchar.h
; prototype: int mbsinit(const mbstate_t *ps)
; standard: C17 7.29.6.2.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:unicode-scalar, reference:mbstate-transition, diff:glibc
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return nonzero when the supplied conversion state is initial or the pointer is null.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global mbsinit:function

section .text.mbsinit alloc exec nowrite progbits
mbsinit:
    mov eax, 1
    test rdi, rdi
    jz .return
    cmp dword [rdi + 4], 0
    je .return
    xor eax, eax
.return:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
