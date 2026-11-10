; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: getsockname
; header: sys/socket.h
; prototype: int getsockname(int fd, struct sockaddr *restrict address, socklen_t *restrict length)
; standard: POSIX.1-2024 XSH getsockname
; deps: __errno_location
; errno: EBADF, EFAULT, EINVAL, ENOBUFS, ENOTSOCK
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Return the socket local address and actual address length.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global getsockname:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.getsockname alloc exec nowrite progbits
getsockname:
    movsxd rdi, edi
    sub rsp, 8
    mov qword [rsp], 0
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 51
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
