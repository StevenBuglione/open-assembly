; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: sendto
; header: sys/socket.h
; prototype: ssize_t sendto(int fd, const void *buffer, size_t length, int flags, const struct sockaddr *address, socklen_t address_length)
; standard: POSIX.1-2024 XSH sendto
; deps: __errno_location
; errno: EACCES, EAGAIN, EBADF, ECONNRESET, EDESTADDRREQ, EFAULT, EINTR, EINVAL, EISCONN, EMSGSIZE, ENOBUFS, ENOMEM, ENOTCONN, ENOTSOCK, EOPNOTSUPP, EPIPE
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32, ecx:s32, r9d:u32
; variadic: false
; semantics: Send data to the optional destination address.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global sendto:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.sendto alloc exec nowrite progbits
sendto:
    movsxd rdi, edi
    movsxd rcx, ecx
    mov r9d, r9d
    sub rsp, 8
    mov [rsp], r9
    mov r9, r8
    mov r8, rcx
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    mov edi, 44
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
