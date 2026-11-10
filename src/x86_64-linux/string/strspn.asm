; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strspn
; header: string.h
; prototype: size_t strspn(const char *s, const char *accept)
; standard: C17 7.24.5.6
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:byte-strings
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the number of initial bytes of s that occur in accept.
; semantics: If accept is empty, return zero. Neither string terminator counts as a set member.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strspn:function

section .text.strspn alloc exec nowrite progbits
strspn:
    xor eax, eax
.next:
    mov cl, [rdi + rax]
    test cl, cl
    jz .done
    mov r8, rsi
.check_set:
    mov dl, [r8]
    test dl, dl
    jz .done
    cmp dl, cl
    je .continue
    inc r8
    jmp .check_set
.continue:
    inc rax
    jmp .next
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
