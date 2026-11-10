; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: epoll_create
; header: sys/epoll.h
; prototype: int epoll_create(int size)
; standard: Extension ABI epoll_create
; deps: __errno_location
; errno: EINVAL, EMFILE, ENFILE, ENOMEM
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Create an epoll instance using the legacy positive size argument.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global epoll_create:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.epoll_create alloc exec nowrite progbits
epoll_create:
    movsxd rdi, edi
    sub rsp, 8
    mov qword [rsp], 0
    mov rsi, rdi
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 213
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
