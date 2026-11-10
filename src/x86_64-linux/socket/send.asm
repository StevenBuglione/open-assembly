; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: send
; header: sys/socket.h
; prototype: ssize_t send(int fd, const void *buffer, size_t length, int flags)
; standard: POSIX.1-2024 XSH send
; deps: __errno_location
; errno: EACCES, EAGAIN, EBADF, ECONNRESET, EDESTADDRREQ, EFAULT, EINTR, EINVAL, EISCONN, EMSGSIZE, ENOBUFS, ENOMEM, ENOTCONN, ENOTSOCK, EOPNOTSUPP, EPIPE
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32, ecx:s32
; variadic: false
; semantics: Send bytes through a connected socket using Linux send flags.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global send:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.send alloc exec nowrite progbits
send:
    movsxd rdi, edi
    movsxd rcx, ecx
    sub rsp, 8
    mov qword [rsp], 0
    mov r8, rcx
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    xor r9d, r9d
    mov edi, 44
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
