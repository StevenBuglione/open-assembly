; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: epoll_create1
; header: sys/epoll.h
; prototype: int epoll_create1(int flags)
; standard: Extension ABI epoll_create1
; deps: __errno_location
; errno: EINVAL, EMFILE, ENFILE, ENOMEM
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Create an epoll instance with the supplied flags.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global epoll_create1:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.epoll_create1 alloc exec nowrite progbits
epoll_create1:
    movsxd rdi, edi
    sub rsp, 8
    mov qword [rsp], 0
    mov rsi, rdi
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 291
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
