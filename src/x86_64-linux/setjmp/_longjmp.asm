; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: _longjmp
; header: setjmp.h
; prototype: _Noreturn void _longjmp(jmp_buf env, int value)
; standard: Extension ABI _longjmp
; deps: longjmp
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:lua-posix-abi
; provenance: original
; narrow_args: esi:s32
; variadic: false
; noreturn: true
; semantics: Resume a live context from _setjmp or setjmp in the same thread.
; semantics: Resume with value or with one for a zero input. Leave the signal mask and floating-point controls in effect.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global _longjmp:function
extern longjmp:function

section .text._longjmp alloc exec nowrite progbits
_longjmp:
    push rbp
    mov rbp, rsp
    movsxd rsi, esi
    call longjmp
    ud2

section .note.GNU-stack noalloc noexec nowrite progbits
