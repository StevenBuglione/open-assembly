; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: inet_ntoa
; header: arpa/inet.h
; prototype: char *inet_ntoa(struct in_addr address)
; standard: POSIX.1-2024 XSH inet_ntoa
; deps: pthread_self
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:posix-ipv4-address, diff:glibc, diff:musl, suite:libc-test
; provenance: original
; narrow_args: edi:u32
; variadic: false
; semantics: Return the IPv4 address in dotted decimal and preserve errno.
; semantics: The text is stored in the calling thread and is overwritten by a later call on that thread.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global inet_ntoa:function
extern pthread_self:function
extern __al_inet_text4:function

section .text.inet_ntoa alloc exec nowrite progbits
inet_ntoa:
    push rbx
    push r12
    sub rsp, 8
    mov ebx, edi
    call pthread_self
    lea r12, [rax + 0xe0]        ; thread-owned dotted decimal buffer
    mov [r12 + 16], ebx          ; network order address bytes
    lea rdi, [r12 + 16]
    mov rsi, r12
    call __al_inet_text4
    mov byte [r12 + rax], 0
    mov rax, r12
    add rsp, 8
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
