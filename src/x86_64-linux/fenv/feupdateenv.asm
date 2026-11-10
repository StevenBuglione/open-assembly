; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: feupdateenv
; header: fenv.h
; prototype: int feupdateenv(const fenv_t *envp)
; standard: C17 7.6.4.4
; deps: fetestexcept, fesetenv, feraiseexcept
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:fenv-hardware
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Restore a saved or default environment and raise the exception flags set before restoration.
; semantics: Return zero if execution continues.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global feupdateenv:function
extern fetestexcept:function
extern fesetenv:function
extern feraiseexcept:function

section .text.feupdateenv alloc exec nowrite progbits
feupdateenv:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov rbx, rdi
    mov edi, 61
    call fetestexcept
    mov r12d, eax
    mov rdi, rbx
    call fesetenv
    mov edi, r12d
    call feraiseexcept
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
