; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: setjmp
; header: setjmp.h
; prototype: int setjmp(jmp_buf env)
; standard: C17 7.13.1.1, POSIX.1-2024 XSH setjmp
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:sysv-jump-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Save the current callee-saved registers, caller stack pointer, and return address.
; semantics: Return zero when saving. A later valid longjmp can resume the caller with a nonzero result.
; semantics: Leave the signal mask and floating-point state unchanged.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global setjmp:function

section .text.setjmp alloc exec nowrite progbits
setjmp:
    mov [rdi], rbx
    mov [rdi + 8], rbp
    mov [rdi + 16], r12
    mov [rdi + 24], r13
    mov [rdi + 32], r14
    mov [rdi + 40], r15
    lea rax, [rsp + 8]
    mov [rdi + 48], rax
    mov rax, [rsp]
    mov [rdi + 56], rax
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
