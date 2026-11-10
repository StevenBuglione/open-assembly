; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: recv
; header: sys/socket.h
; prototype: ssize_t recv(int fd, void *buffer, size_t length, int flags)
; standard: POSIX.1-2024 XSH recv
; deps: __errno_location
; errno: EAGAIN, EBADF, ECONNREFUSED, EFAULT, EINTR, EINVAL, ENOMEM, ENOTCONN, ENOTSOCK
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32, ecx:s32
; variadic: false
; semantics: Receive bytes through a socket using Linux receive flags.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global recv:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.recv alloc exec nowrite progbits
recv:
    movsxd rdi, edi
    movsxd rcx, ecx
    sub rsp, 8
    mov qword [rsp], 0
    mov r8, rcx
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    xor r9d, r9d
    mov edi, 45
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
