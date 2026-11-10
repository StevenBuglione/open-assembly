; Original lookup for a valid fixed or recurring POSIX rule. Inputs: zone
; and bounded timestamp. Outputs: offset, name, and DST in RAX/RDX/RCX.
bits 64
default rel

global __al_tz_rule_lookup:function
extern __al_gregorian_split:function
extern __al_tz_rule_instant:function

section .text.__al_tz_rule_lookup alloc exec nowrite progbits
__al_tz_rule_lookup:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r12, rdi
    cmp qword [r12 + 104], 1
    je .standard
    mov r13, rsi
    mov rax, r13
    add rax, [r12 + 112]
    cqo
    mov r9d, 86400
    idiv r9
    test rdx, rdx
    jns .day
    dec rax
.day:
    mov rdi, rax
    call __al_gregorian_split
    lea r14, [rax - 1]           ; check adjoining years for shifted rules
    mov r15, 0x8000000000000000
    xor ebx, ebx
    mov qword [rsp], 3
.year:
    mov rdi, r12
    mov rsi, r14
    lea rdx, [r12 + 144]
    xor ecx, ecx
    call __al_tz_rule_instant
    cmp rax, r13
    jg .end
    cmp rax, r15
    jl .end
    mov r15, rax
    mov ebx, 1                  ; start wins ties for all-year DST
.end:
    mov rdi, r12
    mov rsi, r14
    lea rdx, [r12 + 192]
    mov ecx, 1
    call __al_tz_rule_instant
    cmp rax, r13
    jg .next
    cmp rax, r15
    jle .next
    mov r15, rax
    xor ebx, ebx
.next:
    inc r14
    dec qword [rsp]
    jnz .year
    test ebx, ebx
    jz .standard
    mov rax, [r12 + 120]
    mov rdx, [r12 + 136]
    mov ecx, 1
    jmp .done
.standard:
    mov rax, [r12 + 112]
    mov rdx, [r12 + 128]
    xor ecx, ecx
.done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
