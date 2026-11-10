; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strcmp
; header: string.h
; prototype: int strcmp(const char *a, const char *b)
; standard: C17 7.24.4.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:byte-strings
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Compare the strings including NUL as unsigned bytes. Return the sign of the first difference or zero if equal.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strcmp:function

section .text.strcmp alloc exec nowrite progbits
strcmp:
.next:
    movzx eax, byte [rdi]
    movzx ecx, byte [rsi]
    cmp eax, ecx
    jne .difference
    test eax, eax
    jz .done
    inc rdi
    inc rsi
    jmp .next
.difference:
    sub eax, ecx
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
