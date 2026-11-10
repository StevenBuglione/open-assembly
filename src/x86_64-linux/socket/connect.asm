; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: connect
; header: sys/socket.h
; prototype: int connect(int fd, const struct sockaddr *address, socklen_t length)
; standard: POSIX.1-2024 XSH connect
; deps: __errno_location
; errno: EACCES, EADDRINUSE, EADDRNOTAVAIL, EAFNOSUPPORT, EAGAIN, EALREADY, EBADF, ECONNREFUSED, EFAULT, EINPROGRESS, EINTR, EISCONN, ENETUNREACH, ENOTSOCK, ETIMEDOUT
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32, edx:u32
; variadic: false
; semantics: Connect or initiate a nonblocking connection to the supplied address.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global connect:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.connect alloc exec nowrite progbits
connect:
    movsxd rdi, edi
    mov edx, edx
    sub rsp, 8
    mov qword [rsp], 0
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 42
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
