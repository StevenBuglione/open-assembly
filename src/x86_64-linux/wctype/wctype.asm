; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wctype
; header: wctype.h
; prototype: wctype_t wctype(const char *property)
; standard: C17 7.30.2.2.2
; deps: strcmp
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:unicode-16.0.0, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return a descriptor for a standard class name, or zero for an unknown name.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wctype:function
extern strcmp:function

section .text.wctype alloc exec nowrite progbits
wctype:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    lea r12, [rel names]
    mov r13d, 1
.next:
    mov rdi, rbx
    mov rsi, r12
    call strcmp
    test eax, eax
    jz .found
    add r12, 8
    shl r13d, 1
    cmp r13d, 2048
    jbe .next
    xor r13d, r13d
.found:
    mov eax, r13d
    pop r13
    pop r12
    pop rbx
    ret

section .rodata alloc noexec nowrite progbits
names:
    db "alnum", 0, 0, 0
    db "alpha", 0, 0, 0
    db "blank", 0, 0, 0
    db "cntrl", 0, 0, 0
    db "digit", 0, 0, 0
    db "graph", 0, 0, 0
    db "lower", 0, 0, 0
    db "print", 0, 0, 0
    db "punct", 0, 0, 0
    db "space", 0, 0, 0
    db "upper", 0, 0, 0
    db "xdigit", 0, 0

section .note.GNU-stack noalloc noexec nowrite progbits
