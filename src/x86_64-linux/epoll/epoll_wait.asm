; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: epoll_wait
; header: sys/epoll.h
; prototype: int epoll_wait(int epfd, struct epoll_event *events, int capacity, int timeout)
; standard: Extension ABI epoll_wait
; deps: __errno_location
; errno: EBADF, EFAULT, EINTR, EINVAL
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32, edx:s32, ecx:s32
; variadic: false
; semantics: Wait for up to capacity packed readiness records.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global epoll_wait:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.epoll_wait alloc exec nowrite progbits
epoll_wait:
    movsxd rdi, edi
    movsxd rdx, edx
    movsxd rcx, ecx
    sub rsp, 8
    mov qword [rsp], 0
    mov r8, rcx
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    xor r9d, r9d
    mov edi, 232
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
