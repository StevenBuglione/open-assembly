; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: recvmsg
; header: sys/socket.h
; prototype: ssize_t recvmsg(int fd, struct msghdr *message, int flags)
; standard: POSIX.1-2024 XSH recvmsg
; deps: __errno_location
; errno: EAGAIN, EBADF, ECONNREFUSED, EFAULT, EINTR, EINVAL, ENOMEM, ENOTCONN, ENOTSOCK
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32, edx:s32
; variadic: false
; semantics: Receive a Linux scatter-gather message and update its ancillary lengths and flags.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global recvmsg:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.recvmsg alloc exec nowrite progbits
recvmsg:
    movsxd rdi, edi
    movsxd rdx, edx
    sub rsp, 8
    mov qword [rsp], 0
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 47
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
