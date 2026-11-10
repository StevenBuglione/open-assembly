; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: siglongjmp
; header: setjmp.h
; prototype: _Noreturn void siglongjmp(sigjmp_buf env, int val)
; standard: POSIX.1-2024 XSH siglongjmp
; deps: longjmp, sigprocmask
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:sysv-jump-abi
; provenance: original
; narrow_args: esi:s32
; variadic: false
; noreturn: true
; semantics: Restore the saved signal mask when the environment recorded one.
; semantics: Resume the live calling-thread context with val when nonzero or one when val is zero.
; semantics: Preserve current floating-point control state. The restore call does not return.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global siglongjmp:function
extern sigprocmask:function
extern longjmp:function

section .text.siglongjmp alloc exec nowrite progbits
siglongjmp:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov rbx, rdi
    movsxd r12, esi
    cmp dword [rbx + 64], 0
    je .resume
    mov edi, 2                    ; SIG_SETMASK
    lea rsi, [rbx + 72]
    xor edx, edx
    call sigprocmask
.resume:
    mov rdi, rbx
    mov rsi, r12
    call longjmp
    ud2

section .note.GNU-stack noalloc noexec nowrite progbits
