; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wctrans
; header: wctype.h
; prototype: wctrans_t wctrans(const char *property)
; standard: C17 7.30.3.2.2
; deps: strcmp
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:unicode-16.0.0, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return a descriptor for tolower or toupper, or zero for an unknown name.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global wctrans:function
extern strcmp:function

section .text.wctrans alloc exec nowrite progbits
wctrans:
    push rbx
    mov rbx, rdi
    lea rsi, [rel lower]
    call strcmp
    test eax, eax
    jz .lower
    mov rdi, rbx
    lea rsi, [rel upper]
    call strcmp
    test eax, eax
    jz .upper
    xor eax, eax
    jmp .done
.lower:
    mov eax, 1
    jmp .done
.upper:
    mov eax, 2
.done:
    pop rbx
    ret

section .rodata alloc noexec nowrite progbits
lower: db "tolower", 0
upper: db "toupper", 0

section .note.GNU-stack noalloc noexec nowrite progbits
