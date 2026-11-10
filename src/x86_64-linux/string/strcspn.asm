; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strcspn
; header: string.h
; prototype: size_t strcspn(const char *s, const char *reject)
; standard: C17 7.24.5.3
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:byte-strings
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the number of bytes in the initial segment of s containing no byte present in reject.
; semantics: If reject is empty, return the length of s. Neither string terminator counts as a set member.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strcspn:function

section .text.strcspn alloc exec nowrite progbits
strcspn:
    xor eax, eax
.next:
    mov cl, [rdi + rax]
    test cl, cl
    jz .done
    mov r8, rsi
.check_set:
    mov dl, [r8]
    test dl, dl
    jz .continue
    cmp dl, cl
    je .done
    inc r8
    jmp .check_set
.continue:
    inc rax
    jmp .next
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
