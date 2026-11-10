; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: getsockopt
; header: sys/socket.h
; prototype: int getsockopt(int fd, int level, int option, void *restrict value, socklen_t *restrict length)
; standard: POSIX.1-2024 XSH getsockopt
; deps: __errno_location
; errno: EBADF, EFAULT, EINVAL, ENOPROTOOPT, ENOTSOCK
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32, esi:s32, edx:s32
; variadic: false
; semantics: Read the socket option value and returned length.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global getsockopt:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.getsockopt alloc exec nowrite progbits
getsockopt:
    movsxd rdi, edi
    movsxd rsi, esi
    movsxd rdx, edx
    sub rsp, 8
    mov qword [rsp], 0
    mov r9, r8
    mov r8, rcx
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    mov edi, 55
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
