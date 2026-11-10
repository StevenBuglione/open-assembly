; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: getnameinfo
; header: netdb.h
; prototype: int getnameinfo(const struct sockaddr *restrict address, socklen_t address_length, char *restrict host, socklen_t host_length, char *restrict service, socklen_t service_length, int flags)
; standard: POSIX.1-2024 XSH getnameinfo
; deps: __errno_location, calloc, clock_gettime, close, connect, fclose, feof, fgetc, fgets, fopen, free, getsockopt, inet_ntop, inet_pton, ioctl, malloc, memcmp, memcpy, poll, recv, send, socket, snprintf, strchr, strcmp, strlen
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:rfc3493, reference:rfc4007, reference:local-netdb, reference:rfc1035, reference:rfc3596, diff:glibc, diff:musl
; provenance: original
; narrow_args: esi:u32, ecx:u32, r9d:u32
; variadic: false
; semantics: Use configured DNS nameservers with bounded failover, deadlines and retry rounds.
; semantics: Append a scoped IPv6 interface name or decimal scope ID to numeric host output.
; semantics: Render an IPv4 or IPv6 socket address as numeric, local-file or PTR host text and numeric or local-file service text.
; semantics: Publish requested output strings only if both fit, otherwise return an EAI code. Preserve errno.
; semantics: Use local host names before DNS. Fall back to numeric output unless a name is required.
; semantics: Support numeric host and service, local short names, required host names, and UDP service selection.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global getnameinfo:function
extern __al_gni_host:function
extern __al_gni_service:function
extern __errno_location:function
extern calloc:function
extern free:function
extern memcpy:function
extern strlen:function

section .text.getnameinfo alloc exec nowrite progbits
getnameinfo:
    mov r10d, [rsp + 8]         ; seventh argument, flags
    mov esi, esi
    mov ecx, ecx
    mov r9d, r9d
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 48
    mov r12, rdi                ; sockaddr
    mov r13, rdx                ; caller host buffer
    mov r14, r8                 ; caller service buffer
    mov r15d, r10d              ; flags
    xor ebx, ebx                ; context once allocated
    mov [rsp], rcx              ; host capacity
    mov [rsp + 8], r9           ; service capacity
    mov [rsp + 32], rsi         ; sockaddr length before allocating
    call __errno_location
    mov [rsp + 16], rax
    mov eax, [rax]
    mov [rsp + 24], eax
    test r15d, 0xffffffe0
    jnz .bad_flags
    cmp qword [rsp], 0
    jne .service_capacity
    xor r13d, r13d
.service_capacity:
    cmp qword [rsp + 8], 0
    jne .requested_output
    xor r14d, r14d
.requested_output:
    mov rax, r13
    or rax, r14
    jz .missing_output
    cmp qword [rsp + 32], 2
    jb .bad_family
    movzx eax, word [r12]
    cmp eax, 2                  ; AF_INET
    jne .test_ipv6
    cmp qword [rsp + 32], 16
    jb .bad_family
    jmp .allocate
.test_ipv6:
    cmp eax, 10                 ; AF_INET6
    jne .bad_family
    cmp qword [rsp + 32], 28
    jb .bad_family
.allocate:
    mov edi, 1
    mov esi, 5184
    call calloc
    test rax, rax
    jz .no_memory
    mov rbx, rax
    test r13, r13
    jz .service
    mov rdi, rbx
    mov rsi, r12
    mov edx, r15d
    call __al_gni_host
    test eax, eax
    jnz .finish
    lea rdi, [rbx + 64]
    call strlen
    inc rax
    cmp rax, [rsp]
    ja .overflow
    mov [rsp + 32], rax
.service:
    test r14, r14
    jz .publish_host
    mov rdi, rbx
    movzx esi, word [r12 + 2]
    rol si, 8                   ; host-order port
    mov edx, r15d
    call __al_gni_service
    test eax, eax
    jnz .finish
    lea rdi, [rbx + 320]
    call strlen
    inc rax
    cmp rax, [rsp + 8]
    ja .overflow
    mov [rsp + 40], rax
.publish_host:
    test r13, r13
    jz .publish_service
    mov rdi, r13
    lea rsi, [rbx + 64]
    mov rdx, [rsp + 32]
    call memcpy
.publish_service:
    test r14, r14
    jz .success
    mov rdi, r14
    lea rsi, [rbx + 320]
    mov rdx, [rsp + 40]
    call memcpy
.success:
    xor eax, eax
    jmp .finish
.bad_flags:
    mov eax, -1                 ; EAI_BADFLAGS
    jmp .finish
.missing_output:
    mov eax, -2                 ; EAI_NONAME
    jmp .finish
.bad_family:
    mov eax, -6                 ; EAI_FAMILY
    jmp .finish
.no_memory:
    mov eax, -10                ; EAI_MEMORY
    jmp .finish
.overflow:
    mov eax, -12                ; EAI_OVERFLOW
.finish:
    mov [rsp + 28], eax
    test rbx, rbx
    jz .restore_errno
    mov rdi, rbx
    call free
.restore_errno:
    mov rcx, [rsp + 16]
    mov edx, [rsp + 24]
    mov [rcx], edx
    mov eax, [rsp + 28]
    add rsp, 48
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
