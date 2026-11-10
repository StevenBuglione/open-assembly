; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: setsockopt
; header: sys/socket.h
; prototype: int setsockopt(int fd, int level, int option, const void *value, socklen_t length)
; standard: POSIX.1-2024 XSH setsockopt
; deps: __errno_location
; errno: EBADF, EFAULT, EINVAL, ENOPROTOOPT, ENOTSOCK
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32, esi:s32, edx:s32, r8d:u32
; variadic: false
; semantics: Set the socket option from the supplied bytes.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global setsockopt:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.setsockopt alloc exec nowrite progbits
setsockopt:
    movsxd rdi, edi
    movsxd rsi, esi
    movsxd rdx, edx
    mov r8d, r8d
    sub rsp, 8
    mov qword [rsp], 0
    mov r9, r8
    mov r8, rcx
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    mov edi, 54
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
