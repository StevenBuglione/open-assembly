; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: wait
; header: sys/wait.h
; prototype: pid_t wait(int *wstatus)
; standard: POSIX.1-2024 XSH wait
; deps: waitpid
; errno: ECHILD, EFAULT, EINTR
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-process-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Wait for any child with the same semantics as waitpid with pid -1 and options zero.
; semantics: A null status pointer is accepted. Return the child ID or -1 and errno on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global $wait:function
extern waitpid:function

section .text.wait alloc exec nowrite progbits
$wait:
    push rbp
    mov rbp, rsp
    mov rsi, rdi
    mov edi, -1
    xor edx, edx
    call waitpid
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
