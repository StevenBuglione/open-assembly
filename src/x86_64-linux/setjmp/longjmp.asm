; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: longjmp
; header: setjmp.h
; prototype: _Noreturn void longjmp(jmp_buf env, int val)
; standard: C17 7.13.2.1
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:sysv-jump-abi
; provenance: original
; narrow_args: esi:s32
; variadic: false
; noreturn: true
; semantics: Resume a still-live environment saved in the calling thread.
; semantics: Restore the saved callee-saved registers and resume stack and instruction pointers.
; semantics: Resume the save call with val when nonzero or one when val is zero.
; semantics: Preserve the signal mask and current floating-point control state. The restore call does not return.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global longjmp:function

section .text.longjmp alloc exec nowrite progbits
longjmp:
    movsxd rax, esi
    test eax, eax
    jnz .restore
    mov eax, 1
.restore:
    mov r11, [rdi + 56]
    mov r10, [rdi + 48]
    mov rbx, [rdi]
    mov rbp, [rdi + 8]
    mov r12, [rdi + 16]
    mov r13, [rdi + 24]
    mov r14, [rdi + 32]
    mov r15, [rdi + 40]
    mov rsp, r10
    jmp r11

section .note.GNU-stack noalloc noexec nowrite progbits
