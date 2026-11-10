; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: __stack_chk_fail
; header: compiler_rt.h
; prototype: _Noreturn void __stack_chk_fail(void)
; standard: Runtime ABI __stack_chk_fail
; deps: _exit
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:runtime-abi, reference:linux-wait-status
; provenance: original
; narrow_args: -
; variadic: false
; noreturn: true
; semantics: Compiler stack-protector failure entry; never returns or invokes atexit callbacks.
; semantics: Write open-assembly: stack smashing detected followed by a newline to standard error on a best-effort basis.
; semantics: Terminate by default SIGABRT; use exit status 134 if the signal path returns without terminating.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global __stack_chk_fail:function
extern __al_diagnostic:function
extern __al_abort:function

section .text.__stack_chk_fail alloc exec nowrite progbits
__stack_chk_fail:
    push rbp
    mov rbp, rsp
    lea rdi, [rel stack_failure]
    mov esi, 39
    call __al_diagnostic
    call __al_abort
    ud2

section .rodata.__stack_chk_fail alloc noexec nowrite progbits
stack_failure:
    db "open-assembly: stack smashing detected", 10

section .note.GNU-stack noalloc noexec nowrite progbits
