; Merge one checked RTM_GETADDR dump datagram into a family mask.
; RDI bytes, RSI length, RDX mask address. Return 0, 1 on DONE, or -errno.
bits 64
default rel

global __al_gai_addrconfig_parse:function

section .text.__al_gai_addrconfig_parse alloc exec nowrite progbits
__al_gai_addrconfig_parse:
    test rdi, rdi
    jz .invalid
    test rdx, rdx
    jz .invalid
    cmp rsi, 16
    jb .invalid
    cmp rsi, 32768
    ja .invalid
    mov rax, rdi
    add rax, rsi
    jc .invalid
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 48
    mov rbx, rdi                ; netlink message cursor
    mov r12, rax                ; datagram end
    mov r13, rdx                ; publish only after the whole datagram checks
    mov r14d, [r13]

.message:
    mov rdx, r12
    sub rdx, rbx
    cmp rdx, 16
    jb .malformed
    mov eax, [rbx]              ; nlmsg_len
    cmp eax, 16
    jb .malformed
    lea rcx, [rax + 3]
    and rcx, -4
    cmp rcx, rdx
    ja .malformed
    lea r15, [rbx + rax]        ; logical end, excluding netlink padding
    lea rcx, [rbx + rcx]
    mov [rsp], rcx
    cmp dword [rbx + 8], 1      ; nlmsg_seq
    jne .malformed
    test word [rbx + 6], 16     ; NLM_F_DUMP_INTR
    jnz .interrupted
    movzx ecx, word [rbx + 4]   ; nlmsg_type
    cmp ecx, 20                 ; RTM_NEWADDR
    je .address
    cmp ecx, 3                  ; NLMSG_DONE
    je .done
    cmp ecx, 2                  ; NLMSG_ERROR
    je .error
    cmp ecx, 1                  ; NLMSG_NOOP
    je .advance
    jmp .malformed

.error:
    cmp eax, 20
    jb .malformed
    cmp dword [rbx + 16], 0
    jl .interrupted
    jne .malformed
    jmp .advance
.done:
    cmp r12, [rsp]
    jne .malformed
    cmp eax, 16
    je .complete
    cmp eax, 20
    jb .malformed
    cmp dword [rbx + 16], 0
    jl .interrupted
    jne .malformed
.complete:
    mov eax, 1
    jmp .publish

.address:
    cmp eax, 24                 ; fixed ifaddrmsg after nlmsghdr
    jb .malformed
    movzx eax, byte [rbx + 16]  ; ifa_family
    mov ecx, 4
    cmp eax, 2
    je .attributes
    mov ecx, 16
    cmp eax, 10
    jne .advance
.attributes:
    mov [rsp + 8], ecx
    movzx eax, byte [rbx + 18]  ; ifa_flags, superseded by IFA_FLAGS
    mov [rsp + 12], eax
    mov qword [rsp + 16], 0     ; IFA_ADDRESS
    mov qword [rsp + 24], 0     ; IFA_LOCAL
    mov dword [rsp + 32], 0     ; IFA_FLAGS seen
    lea rdi, [rbx + 24]
.attribute:
    cmp rdi, r15
    je .pick_address
    mov rdx, r15
    sub rdx, rdi
    cmp rdx, 4
    jb .malformed
    movzx eax, word [rdi]       ; rta_len
    cmp eax, 4
    jb .malformed
    lea rsi, [rax + 3]
    and rsi, -4
    cmp rsi, rdx
    ja .malformed
    movzx ecx, word [rdi + 2]   ; rta_type
    and ecx, 0x3fff
    lea r8, [rdi + 4]
    sub eax, 4
    cmp ecx, 1
    je .address_attribute
    cmp ecx, 2
    je .local_attribute
    cmp ecx, 8
    jne .next_attribute
    cmp eax, 4
    jne .malformed
    cmp dword [rsp + 32], 0
    jne .malformed
    mov eax, [r8]
    mov [rsp + 12], eax
    mov dword [rsp + 32], 1
    jmp .next_attribute
.address_attribute:
    cmp eax, [rsp + 8]
    jne .malformed
    cmp qword [rsp + 16], 0
    jne .malformed
    mov [rsp + 16], r8
    jmp .next_attribute
.local_attribute:
    cmp eax, [rsp + 8]
    jne .malformed
    cmp qword [rsp + 24], 0
    jne .malformed
    mov [rsp + 24], r8
.next_attribute:
    add rdi, rsi
    jmp .attribute

.pick_address:
    test dword [rsp + 12], 0x48 ; IFA_F_DADFAILED | IFA_F_TENTATIVE
    jnz .advance
    mov rax, [rsp + 24]
    test rax, rax
    jnz .configured
    mov rax, [rsp + 16]
    test rax, rax
    jz .advance
.configured:
    cmp dword [rsp + 8], 4
    jne .ipv6
    mov ecx, [rax]
    test ecx, ecx
    jz .advance
    cmp cl, 127
    je .advance
    or r14d, 1
    jmp .advance
.ipv6:
    cmp qword [rax], 0
    jne .ipv6_configured
    mov rcx, [rax + 8]
    test rcx, rcx
    jz .advance
    mov rdx, 0x0100000000000000
    cmp rcx, rdx
    je .advance
.ipv6_configured:
    or r14d, 2
.advance:
    mov rbx, [rsp]
    cmp rbx, r12
    jb .message
    xor eax, eax
.publish:
    mov [r13], r14d
    jmp .return
.malformed:
    mov eax, -5                ; EIO
    jmp .return
.interrupted:
    mov eax, -11               ; EAGAIN
.return:
    add rsp, 48
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.invalid:
    mov eax, -5
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
