; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: vsprintf
; header: stdio.h
; prototype: int vsprintf(char *restrict dest, const char *restrict format, va_list args)
; standard: C17 7.21.6.13
; deps: vsnprintf
; errno: EILSEQ, EINVAL, EOVERFLOW, EIO
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Interpret the integer, floating, string, byte, pointer, count, and percent conversions.
; semantics: Return the byte count excluding the terminator on success, or a negative result on error.
; semantics: Wide c and s encode arguments with the active LC_CTYPE. String precision limits complete multibyte characters by byte count. Count overflow reports EOVERFLOW.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global vsprintf:function
extern vsnprintf:function

section .text.vsprintf alloc exec nowrite progbits
vsprintf:
    push rbp
    mov rbp, rsp
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, -1
    call vsnprintf
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
