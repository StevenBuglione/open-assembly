; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: accept4
; header: sys/socket.h
; prototype: int accept4(int fd, struct sockaddr *restrict address, socklen_t *restrict length, int flags)
; standard: Extension ABI accept4
; deps: __errno_location
; errno: EAGAIN, EBADF, ECONNABORTED, EFAULT, EINTR, EINVAL, EMFILE, ENFILE, ENOBUFS, ENOMEM, ENOTSOCK, EOPNOTSUPP
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32, ecx:s32
; variadic: false
; semantics: Accept a connection with optional atomic nonblocking and close-on-exec flags.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global accept4:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.accept4 alloc exec nowrite progbits
accept4:
    movsxd rdi, edi
    movsxd rcx, ecx
    sub rsp, 8
    mov qword [rsp], 0
    mov r8, rcx
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    xor r9d, r9d
    mov edi, 288
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
