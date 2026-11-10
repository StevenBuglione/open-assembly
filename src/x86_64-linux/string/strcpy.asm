; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strcpy
; header: string.h
; prototype: char *strcpy(char *restrict dest, const char *restrict src)
; standard: C17 7.24.2.3
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:byte-strings
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Copy the source through its terminating NUL and return dest.
; semantics: The source and destination must not overlap.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strcpy:function

section .text.strcpy alloc exec nowrite progbits
strcpy:
    mov rax, rdi
.next:
    mov dl, [rsi]
    mov [rdi], dl
    test dl, dl
    jz .done
    inc rsi
    inc rdi
    jmp .next
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
