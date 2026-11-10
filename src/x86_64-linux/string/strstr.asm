; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strstr
; header: string.h
; prototype: char *strstr(const char *haystack, const char *needle)
; standard: C17 7.24.5.7
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:byte-strings
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the first position in haystack matching all nonzero bytes of needle, or NULL.
; semantics: An empty needle matches at haystack. Do not read beyond either terminator.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strstr:function

section .text.strstr alloc exec nowrite progbits
strstr:
    cmp byte [rsi], 0
    je .found
.try_here:
    mov rdx, rdi
    mov rcx, rsi
.match:
    mov r8b, [rcx]
    test r8b, r8b
    jz .found
    mov r9b, [rdx]
    test r9b, r9b
    jz .absent
    cmp r9b, r8b
    jne .advance
    inc rdx
    inc rcx
    jmp .match
.advance:
    inc rdi
    jmp .try_here
.found:
    mov rax, rdi
    ret
.absent:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
