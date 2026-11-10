; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: inet_pton
; header: arpa/inet.h
; prototype: int inet_pton(int family, const char *restrict source, void *restrict destination)
; standard: POSIX.1-2024 XSH inet_pton
; deps: __errno_location
; errno: EAFNOSUPPORT
; mt_safe: true
; as_safe: false
; oracles: reference:rfc4291, reference:rfc3986, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Parse a numeric IPv4 or IPv6 address into network-order bytes and return one.
; semantics: Return zero for invalid text without changing the destination or errno.
; semantics: Return minus one with EAFNOSUPPORT for other families.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global inet_pton:function
extern __al_inet_parse4:function
extern __errno_location:function

section .text.inet_pton alloc exec nowrite progbits
inet_pton:
    movsxd rdi, edi
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32
    mov r14, rdx                ; destination is written only after validation
    cmp edi, 2                  ; AF_INET
    je .ipv4
    cmp edi, 10                 ; AF_INET6
    jne .unsupported
    mov r13, rsi
    xor ebx, ebx                ; low word of the packed IPv6 value
    xor r12d, r12d              ; high word of the packed IPv6 value
    xor r15d, r15d              ; words in the current part
    mov dword [rsp + 16], -1    ; prefix word count, absent until ::
    cmp byte [r13], 58
    jne .group
    inc r13
    cmp byte [r13], 58
    jne .invalid
    jmp .compress
.group:
    mov r10, r13                ; first digit, also start of dotted suffix
    xor edx, edx
    xor r9d, r9d
.hex_digit:
    movzx ecx, byte [r13]
    lea eax, [rcx - 48]
    cmp eax, 9
    jbe .accumulate
    mov eax, ecx
    or eax, 32
    sub eax, 97
    cmp eax, 5
    ja .group_end
    add eax, 10
.accumulate:
    inc r9d
    cmp r9d, 4
    ja .invalid
    shl edx, 4
    or edx, eax
    inc r13
    jmp .hex_digit
.group_end:
    test r9d, r9d
    jz .invalid
    cmp ecx, 46
    je .embedded_ipv4
    cmp r15d, 8
    jae .invalid
    mov rax, rbx
    shr rax, 48
    shl r12, 16
    or r12, rax
    shl rbx, 16
    or rbx, rdx
    inc r15d
    test ecx, ecx
    jz .finish_ipv6
    cmp ecx, 58
    jne .invalid
    inc r13
    cmp byte [r13], 58
    je .compress
    cmp byte [r13], 0
    je .invalid
    jmp .group
.compress:
    cmp dword [rsp + 16], -1
    jne .invalid
    mov [rsp], rbx
    mov [rsp + 8], r12
    mov [rsp + 16], r15d
    xor ebx, ebx
    xor r12d, r12d
    xor r15d, r15d
    inc r13
    cmp byte [r13], 0
    jne .group
    jmp .finish_ipv6
.embedded_ipv4:
    cmp r15d, 6
    ja .invalid
    mov rdi, r10
    call __al_inet_parse4
    test eax, eax
    jz .return
    bswap edx                   ; insert the suffix in numeric word order
    mov rax, rbx
    shr rax, 32
    shl r12, 32
    or r12, rax
    shl rbx, 32
    or rbx, rdx
    add r15d, 2
.finish_ipv6:
    mov ecx, [rsp + 16]
    cmp ecx, -1
    jne .insert_gap
    cmp r15d, 8
    jne .invalid
    jmp .store_ipv6
.insert_gap:
    lea eax, [rcx + r15]
    cmp eax, 8
    jae .invalid                ; :: must contribute at least one word
    test ecx, ecx
    jz .store_ipv6
    mov rax, [rsp]
    mov rdx, [rsp + 8]
    neg ecx
    add ecx, 8
.shift_prefix:
    mov r8, rax
    shr r8, 48
    shl rdx, 16
    or rdx, r8
    shl rax, 16
    dec ecx
    jnz .shift_prefix
    or rbx, rax
    or r12, rdx
.store_ipv6:
    bswap r12
    bswap rbx
    mov [r14], r12
    mov [r14 + 8], rbx
    mov eax, 1
    jmp .return
.ipv4:
    mov rdi, rsi
    call __al_inet_parse4
    test eax, eax
    jz .return
    mov [r14], edx
    jmp .return
.unsupported:
    call __errno_location
    mov dword [rax], 97         ; EAFNOSUPPORT
    mov eax, -1
    jmp .return
.invalid:
    xor eax, eax
.return:
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
