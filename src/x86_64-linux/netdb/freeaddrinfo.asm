; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: freeaddrinfo
; header: netdb.h
; prototype: void freeaddrinfo(struct addrinfo *list)
; standard: POSIX.1-2024 XSH freeaddrinfo
; deps: free
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:rfc3493, reference:local-netdb, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Free each address information node in the supplied list and its associated storage.
; semantics: Support a detached sublist and a null list. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global freeaddrinfo:function
extern free:function

section .text.freeaddrinfo alloc exec nowrite progbits
freeaddrinfo:
    push rbx
    test rdi, rdi
    jz .return
.next:
    mov rbx, [rdi + 40]         ; each node owns its address and canonical name
    call free
    mov rdi, rbx
    test rdi, rdi
    jnz .next
.return:
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
