; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: vsnprintf
; header: stdio.h
; prototype: int vsnprintf(char *restrict dest, size_t size, const char *restrict format, va_list args)
; standard: C17 7.21.6.12
; deps: -
; errno: EINVAL, EOVERFLOW, EIO
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Interpret the Phase 4 integer, string, byte, pointer, count, and percent conversions.
; semantics: Return the byte count excluding the terminator on success, or a negative result on error.
; semantics: Unsupported floating or wide conversions report EINVAL. Count overflow reports EOVERFLOW.
; semantics: Write at most size-1 bytes and terminate when size is nonzero. Return the full untruncated count. With size zero dest may be NULL.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global vsnprintf:function
extern __al_vformat:function

section .text.vsnprintf alloc exec nowrite progbits
vsnprintf:
    push rbp
    mov rbp, rsp
    xor r8d, r8d
    call __al_vformat
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
