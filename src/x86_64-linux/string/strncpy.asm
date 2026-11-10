; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: strncpy
; header: string.h
; prototype: char *strncpy(char *restrict dest, const char *restrict src, size_t n)
; standard: C17 7.24.2.4
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:byte-strings
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Copy at most n source bytes. If a NUL is reached before n bytes, fill all remaining destination bytes with zeros.
; semantics: Return dest. Do not access either object for n equal to zero or read beyond an encountered NUL.
; semantics: The regions must not overlap. If the source contains no NUL among its first n bytes, the result is not terminated.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global strncpy:function

section .text.strncpy alloc exec nowrite progbits
strncpy:
    mov rax, rdi
    test rdx, rdx
    jz .done
.next:
    mov cl, [rsi]
    mov [rdi], cl
    dec rdx
    jz .done
    inc rdi
    test cl, cl
    jz .pad
    inc rsi
    jmp .next
.pad:
    mov byte [rdi], 0
    inc rdi
    dec rdx
    jnz .pad
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
