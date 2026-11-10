; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: sigpending
; header: signal.h
; prototype: int sigpending(sigset_t *set)
; standard: POSIX.1-2024 XSH sigpending
; deps: __errno_location
; errno: EFAULT, EINVAL
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-signal-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Report the calling thread pending signal mask from Linux and zero public bytes above the low word.
; semantics: Return zero and preserve errno on success. Return -1 and set errno on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global sigpending:function
extern __al_syscall:function
extern __al_syscall_result:function
extern __al_sigset_publish:function

section .text.sigpending alloc exec nowrite progbits
sigpending:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 24
    mov rbx, rdi                  ; output mask
    mov qword [rsp], 0
    mov rsi, rdi
    mov edi, 127                  ; __NR_rt_sigpending
    mov edx, 8
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .error
    mov rdi, rbx
    mov rsi, [rbx]
    call __al_sigset_publish
    jmp .done
.error:
    mov rdi, rax
    call __al_syscall_result
.done:
    add rsp, 24
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
