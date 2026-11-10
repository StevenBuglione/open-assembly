; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: vfprintf
; header: stdio.h
; prototype: int vfprintf(FILE *restrict stream, const char *restrict format, va_list args)
; standard: C17 7.21.6.8
; deps: -
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

global vfprintf:function
extern __al_vformat:function

section .text.vfprintf alloc exec nowrite progbits
vfprintf:
    push rbp
    mov rbp, rsp
    mov rcx, rdx
    mov rdx, rsi
    xor esi, esi
    mov r8d, 1
    call __al_vformat
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
