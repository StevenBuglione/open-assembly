; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: inet_ntop
; header: arpa/inet.h
; prototype: const char *inet_ntop(int family, const void *restrict source, char *restrict destination, socklen_t size)
; standard: POSIX.1-2024 XSH inet_ntop
; deps: __errno_location
; errno: EAFNOSUPPORT, ENOSPC
; mt_safe: true
; as_safe: false
; oracles: reference:rfc5952, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32, ecx:u32
; variadic: false
; semantics: Render a numeric IPv4 or IPv6 address into a null-terminated destination and return its address.
; semantics: Use canonical IPv6 zero compression and dotted-decimal output for IPv4-mapped addresses.
; semantics: Return null on failure without changing the destination. Preserve errno on success.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global inet_ntop:function
extern __al_inet_text4:function
extern __al_inet_text6:function
extern __errno_location:function

section .text.inet_ntop alloc exec nowrite progbits
inet_ntop:
    movsxd rdi, edi
    mov ecx, ecx
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r15d, edi
    mov r13, rsi                ; input bytes
    mov r12, rdx                ; output buffer
    mov r14, rcx                ; output capacity
    mov rdi, r13
    xor esi, esi                ; measure before touching the buffer
    cmp r15d, 2                 ; AF_INET
    je .measure_ipv4
    cmp r15d, 10                ; AF_INET6
    jne .unsupported
    call __al_inet_text6
    jmp .check_size
.measure_ipv4:
    call __al_inet_text4
.check_size:
    mov ebx, eax
    lea rax, [rbx + 1]
    cmp r14, rax
    jb .small_buffer
    mov rdi, r13
    mov rsi, r12
    cmp r15d, 2
    je .write_ipv4
    call __al_inet_text6
    jmp .terminate
.write_ipv4:
    call __al_inet_text4
.terminate:
    mov byte [r12 + rbx], 0
    mov rax, r12
    jmp .return
.unsupported:
    call __errno_location
    mov dword [rax], 97         ; EAFNOSUPPORT
    xor eax, eax
    jmp .return
.small_buffer:
    call __errno_location
    mov dword [rax], 28         ; ENOSPC
    xor eax, eax
.return:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
