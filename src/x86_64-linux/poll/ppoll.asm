; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: ppoll
; header: poll.h
; prototype: int ppoll(struct pollfd fds[], nfds_t count, const struct timespec *timeout, const sigset_t *mask)
; standard: Extension ABI ppoll
; deps: __errno_location
; errno: EFAULT, EINTR, EINVAL, ENOMEM
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Poll with a temporary signal mask and a copied const timeout.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global ppoll:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.ppoll alloc exec nowrite progbits
ppoll:
    sub rsp, 24
    mov rax, rsi
    shr rax, 32
    jnz .invalid_count
    mov qword [rsp], 0
    mov r8, rcx                   ; public signal-mask pointer
    mov r10, rdx                  ; optional const timespec
    mov rdx, rsi
    mov rsi, rdi
    mov r9d, 8
    test r10, r10
    jz .without_timeout
    mov rax, [r10]
    mov [rsp + 8], rax
    mov rax, [r10 + 8]
    mov [rsp + 16], rax
    mov edi, 271
    lea rcx, [rsp + 8]
    call __al_syscall
    jmp .result
.without_timeout:
    xor ecx, ecx
    mov edi, 271
    call __al_syscall
    jmp .result
.invalid_count:
    mov rax, -22                  ; EINVAL
.result:
    mov rdi, rax
    call __al_syscall_result
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
