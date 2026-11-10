; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: recvfrom
; header: sys/socket.h
; prototype: ssize_t recvfrom(int fd, void *restrict buffer, size_t length, int flags, struct sockaddr *restrict address, socklen_t *restrict address_length)
; standard: POSIX.1-2024 XSH recvfrom
; deps: __errno_location
; errno: EAGAIN, EBADF, ECONNREFUSED, EFAULT, EINTR, EINVAL, ENOMEM, ENOTCONN, ENOTSOCK
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32, ecx:s32
; variadic: false
; semantics: Receive data and optionally return its source address.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global recvfrom:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.recvfrom alloc exec nowrite progbits
recvfrom:
    movsxd rdi, edi
    movsxd rcx, ecx
    sub rsp, 8
    mov [rsp], r9
    mov r9, r8
    mov r8, rcx
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    mov edi, 45
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
