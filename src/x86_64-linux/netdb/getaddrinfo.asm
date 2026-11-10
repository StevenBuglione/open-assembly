; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: getaddrinfo
; header: netdb.h
; prototype: int getaddrinfo(const char *restrict node, const char *restrict service, const struct addrinfo *restrict hints, struct addrinfo **restrict result)
; standard: POSIX.1-2024 XSH getaddrinfo
; deps: __errno_location, calloc, clock_gettime, close, connect, fclose, feof, fgetc, fgets, fopen, free, freeaddrinfo, getsockopt, inet_pton, malloc, memcmp, memcpy, poll, recv, recvfrom, send, sendto, socket, strchr, strcmp, strlen, strncmp
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:rfc3493, reference:local-netdb, reference:rfc1035, diff:glibc, diff:musl
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Resolve numeric, local-file and DNS node inputs and numeric or local-file services into an owned IPv4 or IPv6 TCP/UDP address list.
; semantics: Apply resolv.conf search, domain and ndots to forward DNS candidates.
; semantics: Return zero on success or an EAI error and a null result on failure.
; semantics: Preserve errno. The resolver supports AI_PASSIVE, AI_CANONNAME, AI_NUMERICHOST, AI_NUMERICSERV, AI_V4MAPPED, AI_ALL and AI_ADDRCONFIG.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global getaddrinfo:function
extern __al_gai_service:function
extern __al_gai_hosts:function
extern __al_gai_addrconfig:function
extern __al_dns_lookup:function
extern __al_gai_filter:function
extern __al_gai_result:function
extern __errno_location:function
extern calloc:function
extern free:function

section .text.getaddrinfo alloc exec nowrite progbits
getaddrinfo:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov r12, rdi                ; node
    mov r13, rsi                ; service
    mov r14, rdx                ; hints
    mov r15, rcx                ; result location
    mov qword [r15], 0
    xor ebx, ebx                ; resolver context, once allocated
    call __errno_location
    mov [rsp], rax
    mov eax, [rax]
    mov [rsp + 8], eax
    mov rax, r12
    or rax, r13
    jz .missing_input
    test r14, r14
    jz .allocate
    test dword [r14], 0xfffffbc0 ; flags outside the supported resolver mask
    jnz .bad_flags
    mov eax, [r14 + 4]
    test eax, eax               ; AF_UNSPEC
    jz .allocate
    cmp eax, 2                  ; AF_INET
    je .allocate
    cmp eax, 10                 ; AF_INET6
    jne .bad_family
.allocate:
    mov edi, 1
    mov esi, 5184               ; context, 32 addresses, canonical text and file line
    call calloc
    test rax, rax
    jz .no_memory
    mov rbx, rax
    mov dword [rbx + 48], 3   ; enabled IPv4 and IPv6 source families
    xor edx, edx                ; default socket type and protocol
    xor ecx, ecx
    test r14, r14
    jz .service
    mov eax, [r14]
    mov [rbx + 16], eax         ; flags
    mov eax, [r14 + 4]
    mov [rbx + 12], eax         ; family
    mov edx, [r14 + 8]
    mov ecx, [r14 + 12]
.service:
    mov rdi, rbx
    mov rsi, r13
    call __al_gai_service
    test eax, eax
    jnz .finish
    test dword [rbx + 16], 32 ; AI_ADDRCONFIG
    jz .local
    call __al_gai_addrconfig
    test eax, eax
    js .finish
    jz .missing_input
    mov [rbx + 48], eax
.local:
    mov rdi, rbx
    mov rsi, r12
    call __al_gai_hosts
    test eax, eax
    jz .filter
    cmp eax, -2                 ; local EAI_NONAME permits a DNS query
    jne .finish
    test dword [rbx + 16], 4   ; AI_NUMERICHOST
    jnz .finish
    mov rdi, rbx
    mov rsi, r12
    call __al_dns_lookup
    test eax, eax
    jnz .finish
.filter:
    mov rdi, rbx
    call __al_gai_filter
    test eax, eax
    jnz .finish
    mov rdi, rbx
    call __al_gai_result
    test rax, rax
    jz .no_memory
    mov [r15], rax
    xor eax, eax
    jmp .finish
.missing_input:
    mov eax, -2                 ; EAI_NONAME
    jmp .finish
.bad_flags:
    mov eax, -1                 ; EAI_BADFLAGS
    jmp .finish
.bad_family:
    mov eax, -6                 ; EAI_FAMILY
    jmp .finish
.no_memory:
    mov eax, -10                ; EAI_MEMORY
.finish:
    mov [rsp + 12], eax
    test rbx, rbx
    jz .restore_errno
    mov rdi, rbx
    call free
.restore_errno:
    mov rcx, [rsp]
    mov edx, [rsp + 8]
    mov [rcx], edx
    mov eax, [rsp + 12]
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
