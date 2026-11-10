; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: accept
; header: sys/socket.h
; prototype: int accept(int fd, struct sockaddr *restrict address, socklen_t *restrict length)
; standard: POSIX.1-2024 XSH accept
; deps: __errno_location
; errno: EAGAIN, EBADF, ECONNABORTED, EFAULT, EINTR, EINVAL, EMFILE, ENFILE, ENOBUFS, ENOMEM, ENOTSOCK, EOPNOTSUPP
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Accept a connection and optionally return its peer address.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global accept:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.accept alloc exec nowrite progbits
accept:
    movsxd rdi, edi
    sub rsp, 8
    mov qword [rsp], 0
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 43
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
