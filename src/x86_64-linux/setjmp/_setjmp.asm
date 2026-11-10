; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: _setjmp
; header: setjmp.h
; prototype: int _setjmp(jmp_buf env)
; standard: Extension ABI _setjmp
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:lua-posix-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Save the same calling context as setjmp and return zero on the first return.
; semantics: Use the declared returns-twice ABI and preserve the signal mask and floating-point control state.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global _setjmp:function

section .text._setjmp alloc exec nowrite progbits
_setjmp:
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
