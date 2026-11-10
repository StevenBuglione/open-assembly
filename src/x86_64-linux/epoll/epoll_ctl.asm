; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: epoll_ctl
; header: sys/epoll.h
; prototype: int epoll_ctl(int epfd, int operation, int fd, struct epoll_event *event)
; standard: Extension ABI epoll_ctl
; deps: __errno_location
; errno: EBADF, EEXIST, EINVAL, ELOOP, ENOENT, ENOMEM, ENOSPC, EPERM
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32, esi:s32, edx:s32
; variadic: false
; semantics: Add, modify or remove a descriptor registration.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global epoll_ctl:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.epoll_ctl alloc exec nowrite progbits
epoll_ctl:
    movsxd rdi, edi
    movsxd rsi, esi
    movsxd rdx, edx
    sub rsp, 8
    mov qword [rsp], 0
    mov r8, rcx
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    xor r9d, r9d
    mov edi, 233
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
