; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: socketpair
; header: sys/socket.h
; prototype: int socketpair(int domain, int type, int protocol, int sv[2])
; standard: POSIX.1-2024 XSH socketpair
; deps: __errno_location
; errno: EAFNOSUPPORT, EFAULT, EINVAL, EMFILE, ENFILE, EOPNOTSUPP, EPROTONOSUPPORT
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32, esi:s32, edx:s32
; variadic: false
; semantics: Create a connected pair and store its two descriptors.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global socketpair:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.socketpair alloc exec nowrite progbits
socketpair:
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
    mov edi, 53
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
