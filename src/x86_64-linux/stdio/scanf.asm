; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: scanf
; header: stdio.h
; prototype: int scanf(const char *restrict format, ...)
; standard: C17 7.21.6.4
; deps: vscanf
; errno: EINVAL, EIO
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: true
; semantics: Interpret the Phase 4 integer, byte, string, pointer, count, percent and bracket-set conversions.
; semantics: Apply widths and assignment suppression. Preserve the first input byte after a matching item.
; semantics: Return the number of assignments, or EOF if input fails before the first completed conversion.
; semantics: Unsupported floating or wide conversions report EINVAL.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global scanf:function
extern vscanf:function

section .text.scanf alloc exec nowrite progbits
scanf:
    push rbp
    mov rbp, rsp
    sub rsp, 208
    mov [rsp + 32], rdi
    mov [rsp + 40], rsi
    mov [rsp + 48], rdx
    mov [rsp + 56], rcx
    mov [rsp + 64], r8
    mov [rsp + 72], r9
    mov dword [rsp], 8
    mov dword [rsp + 4], 48
    lea rax, [rbp + 16]
    mov [rsp + 8], rax
    lea rax, [rsp + 32]
    mov [rsp + 16], rax
    lea rsi, [rsp]
    call vscanf
    add rsp, 208
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
