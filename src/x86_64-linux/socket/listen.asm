; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: listen
; header: sys/socket.h
; prototype: int listen(int fd, int backlog)
; standard: POSIX.1-2024 XSH listen
; deps: __errno_location
; errno: EADDRINUSE, EBADF, ENOTSOCK, EOPNOTSUPP
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32, esi:s32
; variadic: false
; semantics: Mark a socket as listening with the supplied backlog.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global listen:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.listen alloc exec nowrite progbits
listen:
    movsxd rdi, edi
    movsxd rsi, esi
    sub rsp, 8
    mov qword [rsp], 0
    mov rdx, rsi
    mov rsi, rdi
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 50
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
