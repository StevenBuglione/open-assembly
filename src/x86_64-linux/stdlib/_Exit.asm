; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: _Exit
; header: stdlib.h
; prototype: _Noreturn void _Exit(int status)
; standard: C17 7.22.4.5
; deps: _exit
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:linux-wait-status
; provenance: original
; narrow_args: edi:s32
; variadic: false
; noreturn: true
; semantics: Terminate the process without invoking atexit or signal handlers.
; semantics: The low eight bits of status are available to the parent; the function never returns.
; semantics: Do not flush buffered streams or remove temporary files on this path.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global _Exit:function
extern _exit:function

section .text._Exit alloc exec nowrite progbits
_Exit:
    push rbp
    mov rbp, rsp
    movsxd rdi, edi
    call _exit
    ud2

section .note.GNU-stack noalloc noexec nowrite progbits
