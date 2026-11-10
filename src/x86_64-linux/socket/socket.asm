; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: socket
; header: sys/socket.h
; prototype: int socket(int domain, int type, int protocol)
; standard: POSIX.1-2024 XSH socket
; deps: __errno_location
; errno: EACCES, EAFNOSUPPORT, EINVAL, EMFILE, ENFILE, ENOBUFS, ENOMEM, EPROTONOSUPPORT
; mt_safe: true
; as_safe: false
; oracles: reference:linux-x86-64-network-abi, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32, esi:s32, edx:s32
; variadic: false
; semantics: Create a Linux socket and return its descriptor.
; semantics: Return the Linux result or minus one with TLS errno. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global socket:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.socket alloc exec nowrite progbits
socket:
    movsxd rdi, edi
    movsxd rsi, esi
    movsxd rdx, edx
    sub rsp, 8
    mov qword [rsp], 0
    mov rcx, rdx
    mov rdx, rsi
    mov rsi, rdi
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 41
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
