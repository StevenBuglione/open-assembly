; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: abort
; header: stdlib.h
; prototype: _Noreturn void abort(void)
; standard: C17 7.22.4.1
; deps: raise
; errno: -
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:lua-posix-abi
; provenance: original
; narrow_args: -
; variadic: false
; noreturn: true
; semantics: Unblock SIGABRT and deliver it to the calling thread.
; semantics: If the installed disposition returns or ignores the signal, restore its default and deliver it again.
; semantics: Terminate abnormally without running normal exit callbacks. The abort call does not return.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global abort:function
extern __al_syscall:function
extern raise:function
extern __al_abort:function

section .text.abort alloc exec nowrite progbits
abort:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov qword [rsp + 8], 32      ; SIGABRT bit
    mov esi, 1                    ; SIG_UNBLOCK
    xor ecx, ecx
    mov r8d, 8
    xor r9d, r9d
    mov edi, 14                   ; __NR_rt_sigprocmask
    lea rdx, [rsp + 8]
    call __al_syscall
    mov edi, 6                    ; SIGABRT
    call raise
    call __al_abort
    ud2

section .note.GNU-stack noalloc noexec nowrite progbits
