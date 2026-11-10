; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: poll
; header: poll.h
; prototype: int poll(struct pollfd fds[], nfds_t count, int timeout)
; standard: POSIX.1-2024 XSH poll
; deps: __errno_location
; errno: EFAULT, EINTR, EINVAL, ENOMEM
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edx:s32
; variadic: false
; semantics: Poll the descriptor array for readiness and report returned events.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global poll:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.poll alloc exec nowrite progbits
poll:
    movsxd rdx, edx
    sub rsp, 8
    mov rax, rsi
    shr rax, 32
    jnz .invalid_count
    mov qword [rsp], 0
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 7
    call __al_syscall
    jmp .result
.invalid_count:
    mov rax, -22                  ; EINVAL
.result:
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
