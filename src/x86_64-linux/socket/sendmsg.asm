; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: sendmsg
; header: sys/socket.h
; prototype: ssize_t sendmsg(int fd, const struct msghdr *message, int flags)
; standard: POSIX.1-2024 XSH sendmsg
; deps: __errno_location
; errno: EACCES, EAGAIN, EBADF, ECONNRESET, EDESTADDRREQ, EFAULT, EINTR, EINVAL, EISCONN, EMSGSIZE, ENOBUFS, ENOMEM, ENOTCONN, ENOTSOCK, EOPNOTSUPP, EPIPE
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32, edx:s32
; variadic: false
; semantics: Send a Linux scatter-gather message and any ancillary records.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global sendmsg:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.sendmsg alloc exec nowrite progbits
sendmsg:
    movsxd rdi, edi
    movsxd rdx, edx
    sub rsp, 8
    mov qword [rsp], 0
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 46
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
