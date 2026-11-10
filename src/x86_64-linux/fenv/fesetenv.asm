; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fesetenv
; header: fenv.h
; prototype: int fesetenv(const fenv_t *envp)
; standard: C17 7.6.4.3
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:fenv-hardware
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Install a saved environment or the baseline masked FE_DFL_ENV. Return zero.
; semantics: Restoring flags does not raise exceptions.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fesetenv:function

section .text.fesetenv alloc exec nowrite progbits
fesetenv:
    cmp rdi, -1                  ; FE_DFL_ENV
    je .default
    fldenv [rdi]
    ldmxcsr [rdi + 28]
    xor eax, eax
    ret
.default:
    fninit
    ldmxcsr [rel initial_mxcsr]
    xor eax, eax
    ret

section .rodata.fesetenv alloc noexec nowrite progbits align=4
initial_mxcsr:
    dd 0x1f80

section .note.GNU-stack noalloc noexec nowrite progbits
