; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: bind
; header: sys/socket.h
; prototype: int bind(int fd, const struct sockaddr *address, socklen_t length)
; standard: POSIX.1-2024 XSH bind
; deps: __errno_location
; errno: EACCES, EADDRINUSE, EADDRNOTAVAIL, EBADF, EFAULT, EINVAL, ENOTSOCK
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32, edx:u32
; variadic: false
; semantics: Bind the socket to the supplied address bytes.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global bind:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.bind alloc exec nowrite progbits
bind:
    movsxd rdi, edi
    mov edx, edx
    sub rsp, 8
    mov qword [rsp], 0
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 49
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
