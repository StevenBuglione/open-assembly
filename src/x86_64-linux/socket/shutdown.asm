; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: shutdown
; header: sys/socket.h
; prototype: int shutdown(int fd, int how)
; standard: POSIX.1-2024 XSH shutdown
; deps: __errno_location
; errno: EBADF, EINVAL, ENOTCONN, ENOTSOCK
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32, esi:s32
; variadic: false
; semantics: Shut down the selected directions of the connection.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global shutdown:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.shutdown alloc exec nowrite progbits
shutdown:
    movsxd rdi, edi
    movsxd rsi, esi
    sub rsp, 8
    mov qword [rsp], 0
    mov rdx, rsi
    mov rsi, rdi
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 48
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
