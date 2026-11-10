; Validate the echoed DNS question and find A/AAAA answers for its owner.
; The answer block holds metadata, a canonical wire name, 16 address slots,
; and two 256-byte name scratch areas. See ADR 0017 for the private ABI.
bits 64
default rel

global __al_dns_parse:function
extern __al_dns_name:function
extern memcmp:function
extern memcpy:function

section .text.__al_dns_parse alloc exec nowrite progbits
__al_dns_parse:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 80
    mov r12, rdi                ; response base and byte count
    mov r13, rsi
    mov r14, rdx                ; original query base and byte count
    mov r15, rcx
    mov rbx, r8                 ; answer block
    mov qword [rbx], 0
    cmp r15, 17
    jb .malformed
    cmp r15, 271
    ja .malformed
    cmp r13, 12
    jb .malformed
    cmp r13, 65535
    ja .malformed
    mov ax, [r12]
    cmp ax, [r14]
    jne .unrelated
    movzx eax, word [r12 + 2]
    rol ax, 8
    test eax, 0x8000            ; QR must indicate a response
    jz .unrelated
    test eax, 0x7840            ; standard query opcode, reserved Z clear
    jnz .malformed
    mov [rsp + 8], eax          ; response flags
    cmp word [r12 + 4], 256     ; exactly one echoed question
    jne .unrelated
    mov rdi, r12
    mov rsi, r13
    mov edx, 12
    lea rcx, [rbx + 8]
    call __al_dns_name
    test rax, rax
    jz .malformed
    lea rcx, [rax + 4]
    cmp rcx, r13
    ja .malformed
    mov [rsp], rcx              ; first answer offset
    lea rcx, [r15 - 16]
    cmp rdx, rcx
    jne .unrelated
    mov [rsp + 16], edx         ; current canonical wire name length
    mov ecx, [r14 + r15 - 4]
    cmp ecx, [r12 + rax]
    jne .unrelated
    mov eax, ecx
    shr eax, 16
    cmp eax, 256                ; class IN
    jne .malformed
    rol cx, 8
    movzx eax, cx
    cmp eax, 1
    je .question_type
    cmp eax, 28
    jne .malformed
.question_type:
    mov [rbx + 4], eax
    lea rdi, [rbx + 8]
    lea rsi, [r14 + 12]
    call memcmp
    test eax, eax
    jnz .unrelated
    mov eax, [rsp + 8]
    test eax, 0x0200            ; matching truncated response, retry by TCP
    jnz .truncated
    and eax, 15
    cmp eax, 3                  ; NXDOMAIN
    je .no_answer
    cmp eax, 2                  ; SERVFAIL
    je .temporary
    test eax, eax
    jnz .malformed
    movzx eax, word [r12 + 6]
    rol ax, 8
    mov [rsp + 20], eax         ; number of answer resource records
    mov dword [rsp + 40], 0     ; number of followed CNAME links
.pass:
    mov rax, [rsp]
    mov [rsp + 24], rax         ; cursor for this pass
    mov eax, [rsp + 20]
    mov [rsp + 32], eax         ; remaining records
    mov dword [rsp + 36], 0     ; length of the matching CNAME, if any
.record:
    cmp dword [rsp + 32], 0
    je .finish_pass
    mov rdi, r12
    mov rsi, r13
    mov rdx, [rsp + 24]
    lea rcx, [rbx + 520]
    call __al_dns_name
    test rax, rax
    jz .malformed
    lea rcx, [rax + 10]
    cmp rcx, r13
    ja .malformed
    mov [rsp + 48], rcx         ; RDATA offset
    movzx r8d, word [r12 + rax + 8]
    rol r8w, 8
    mov [rsp + 56], r8          ; RDATA length
    add rcx, r8
    cmp rcx, r13
    ja .malformed
    mov [rsp + 24], rcx         ; next RR cursor
    cmp word [r12 + rax + 2], 256
    jne .next_record
    cmp edx, [rsp + 16]
    jne .next_record
    movzx ecx, word [r12 + rax]
    rol cx, 8
    mov [rsp + 64], ecx         ; RR type
    lea rdi, [rbx + 8]
    lea rsi, [rbx + 520]
    call memcmp
    test eax, eax
    jnz .next_record
    mov eax, [rsp + 64]
    cmp eax, 5
    je .cname
    cmp eax, [rbx + 4]
    jne .next_record
    mov rax, [rsp + 48]
    cmp dword [rbx + 4], 1
    jne .aaaa
    cmp qword [rsp + 56], 4
    jne .malformed
    mov r10d, [r12 + rax]
    xor r11d, r11d
    jmp .unique
.aaaa:
    cmp qword [rsp + 56], 16
    jne .malformed
    mov r10, [r12 + rax]
    mov r11, [r12 + rax + 8]
.unique:
    mov ecx, [rbx]
    lea rax, [rbx + 264]
    xor edx, edx
.seen_address:
    cmp edx, ecx
    jae .store_address
    cmp [rax], r10
    jne .compare_next
    cmp [rax + 8], r11
    je .next_record
.compare_next:
    add rax, 16
    inc edx
    jmp .seen_address
.store_address:
    cmp ecx, 16
    jae .next_record
    mov [rax], r10
    mov [rax + 8], r11
    inc dword [rbx]
    jmp .next_record
.cname:
    mov rdi, r12
    mov rsi, r13
    mov rdx, [rsp + 48]
    lea rcx, [rbx + 776]
    cmp dword [rsp + 36], 0
    je .expand_cname
    lea rcx, [rbx + 520]        ; compare a duplicate alias against the first
.expand_cname:
    call __al_dns_name
    test rax, rax
    jz .malformed
    cmp rax, [rsp + 24]         ; require exact consumption of the RDATA
    jne .malformed
    cmp dword [rsp + 36], 0
    je .remember_alias
    cmp edx, [rsp + 36]
    jne .malformed
    lea rdi, [rbx + 776]
    lea rsi, [rbx + 520]
    call memcmp
    test eax, eax
    jnz .malformed
    jmp .next_record
.remember_alias:
    mov [rsp + 36], edx
.next_record:
    dec dword [rsp + 32]
    jmp .record
.finish_pass:
    cmp dword [rbx], 0
    je .check_alias
    cmp dword [rsp + 36], 0     ; an address owner cannot also be a CNAME
    jne .malformed
    xor eax, eax
    jmp .return
.check_alias:
    mov edx, [rsp + 36]
    test edx, edx
    jz .no_answer
    inc dword [rsp + 40]
    cmp dword [rsp + 40], 8
    ja .malformed
    mov [rsp + 16], edx
    lea rdi, [rbx + 8]
    lea rsi, [rbx + 776]
    call memcpy
    jmp .pass
.unrelated:
    mov eax, 2
    jmp .failure
.truncated:
    mov eax, 1
    jmp .failure
.temporary:
    mov eax, -3                 ; EAI_AGAIN
    jmp .failure
.no_answer:
    mov eax, -2                 ; EAI_NONAME
    jmp .failure
.malformed:
    mov eax, -4                 ; EAI_FAIL
.failure:
    mov dword [rbx], 0
.return:
    add rsp, 80
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
