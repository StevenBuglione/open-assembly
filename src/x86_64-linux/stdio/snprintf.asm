; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: snprintf
; header: stdio.h
; prototype: int snprintf(char *restrict dest, size_t size, const char *restrict format, ...)
; standard: C17 7.21.6.5
; deps: vsnprintf
; errno: EINVAL, EOVERFLOW, EIO
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: true
; semantics: Interpret the Phase 4 integer, string, byte, pointer, count, and percent conversions.
; semantics: Return the byte count excluding the terminator on success, or a negative result on error.
; semantics: Unsupported floating or wide conversions report EINVAL. Count overflow reports EOVERFLOW.
; semantics: Write at most size-1 bytes and terminate when size is nonzero. Return the full untruncated count. With size zero dest may be NULL.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global snprintf:function
extern vsnprintf:function

section .text.snprintf alloc exec nowrite progbits
snprintf:
    push rbp
    mov rbp, rsp
    sub rsp, 208
    mov [rsp + 32], rdi
    mov [rsp + 40], rsi
    mov [rsp + 48], rdx
    mov [rsp + 56], rcx
    mov [rsp + 64], r8
    mov [rsp + 72], r9
    mov dword [rsp], 24
    mov dword [rsp + 4], 48
    lea rax, [rbp + 16]
    mov [rsp + 8], rax
    lea rax, [rsp + 32]
    mov [rsp + 16], rax
    lea rcx, [rsp]
    call vsnprintf
    add rsp, 208
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
