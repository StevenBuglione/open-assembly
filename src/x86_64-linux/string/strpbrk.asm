; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strpbrk
; header: string.h
; prototype: char *strpbrk(const char *s, const char *accept)
; standard: C17 7.24.5.4
; deps: strcspn
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:byte-strings
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the first address in s whose nonzero byte occurs in accept, or NULL when there is no such byte.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strpbrk:function
extern strcspn:function

section .text.strpbrk alloc exec nowrite progbits
strpbrk:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov [rsp], rdi
    call strcspn
    add rax, [rsp]
    cmp byte [rax], 0
    jne .done
    xor eax, eax
.done:
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
