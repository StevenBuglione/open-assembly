; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fegetexceptflag
; header: fenv.h
; prototype: int fegetexceptflag(fexcept_t *flagp, int excepts)
; standard: C17 7.6.2.2
; deps: fetestexcept
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:fenv-hardware
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Store the requested exception flags as an opaque fexcept_t value. Return zero.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fegetexceptflag:function
extern fetestexcept:function

section .text.fegetexceptflag alloc exec nowrite progbits
fegetexceptflag:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8
    mov rbx, rdi
    movsxd rdi, esi
    call fetestexcept
    mov [rbx], ax
    xor eax, eax
    add rsp, 8
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
