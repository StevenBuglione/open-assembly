; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fegetenv
; header: fenv.h
; prototype: int fegetenv(fenv_t *envp)
; standard: C17 7.6.4.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:fenv-hardware
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Save the current x87 environment and MXCSR. Preserve the active environment. Return zero.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fegetenv:function

section .text.fegetenv alloc exec nowrite progbits
fegetenv:
    sub rsp, 32
    fnstenv [rsp]
    fldenv [rsp]
    stmxcsr [rsp + 28]
    mov rax, [rsp]
    mov [rdi], rax
    mov rax, [rsp + 8]
    mov [rdi + 8], rax
    mov rax, [rsp + 16]
    mov [rdi + 16], rax
    mov rax, [rsp + 24]
    mov [rdi + 24], rax
    xor eax, eax
    add rsp, 32
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
