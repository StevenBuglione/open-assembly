; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strcat
; header: string.h
; prototype: char *strcat(char *restrict dest, const char *restrict src)
; standard: C17 7.24.3.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:byte-strings
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Append the source through its NUL to the original destination terminator and return dest.
; semantics: The strings must not overlap and dest must have space for the result.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strcat:function

section .text.strcat alloc exec nowrite progbits
strcat:
    mov rax, rdi
.find_end:
    cmp byte [rdi], 0
    je .append
    inc rdi
    jmp .find_end
.append:
    mov dl, [rsi]
    mov [rdi], dl
    test dl, dl
    jz .done
    inc rdi
    inc rsi
    jmp .append
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
