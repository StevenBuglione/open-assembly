; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: feholdexcept
; header: fenv.h
; prototype: int feholdexcept(fenv_t *envp)
; standard: C17 7.6.4.2
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:fenv-hardware
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Save the current environment, clear exception flags, and mask exceptions in both units.
; semantics: Keep the rounding mode. Return zero.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global feholdexcept:function

section .text.feholdexcept alloc exec nowrite progbits
feholdexcept:
    sub rsp, 32
    fnstenv [rsp]
    stmxcsr [rsp + 28]
    mov rax, [rsp]
    mov [rdi], rax
    mov rax, [rsp + 8]
    mov [rdi + 8], rax
    mov rax, [rsp + 16]
    mov [rdi + 16], rax
    mov rax, [rsp + 24]
    mov [rdi + 24], rax
    or word [rsp], 63
    and word [rsp + 4], 0x7f00
    or dword [rsp + 28], 0x1f80
    and dword [rsp + 28], -64
    fldenv [rsp]
    ldmxcsr [rsp + 28]
    xor eax, eax
    add rsp, 32
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
