; Original selection and ownership for a zone record. Input: stable TZ
; key, or null for /etc/localtime. Return a validated record or null.
bits 64
default rel

global __al_zone_load:function
extern __al_tz_rule_parse:function
extern __al_tzif_parse:function
extern __al_tzif_read:function
extern __al_tzif_leaps:function
extern calloc:function
extern malloc:function
extern free:function
extern strlen:function
extern memcpy:function

section .text.__al_zone_load alloc exec nowrite progbits
__al_zone_load:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r12, rdi
    test r12, r12
    jz .allocate
    cmp byte [r12], 0
    je .fallback
.allocate:
    mov edi, 1
    mov esi, 368                 ; transition context, two rules, two names
    call calloc
    test rax, rax
    jz .fallback
    mov rbx, rax
    xor r13d, r13d                ; optional owned concatenated path
    test r12, r12
    jz .system_path
    cmp byte [r12], 58           ; explicit file interpretation
    je .explicit
    cmp byte [r12], 47
    je .absolute
    mov rdi, r12
    mov rsi, rbx
    mov edx, 167
    call __al_tz_rule_parse
    test eax, eax
    jz .success
    jmp .relative
.explicit:
    inc r12
    cmp byte [r12], 0
    je .free_zone
    cmp byte [r12], 47
    je .absolute
.relative:
    mov rdi, r12
    call strlen
    cmp rax, 4075                ; keep path and terminator within PATH_MAX
    ja .free_zone
    lea r14, [rax + 1]
    lea rdi, [r14 + 20]
    call malloc
    test rax, rax
    jz .free_zone
    mov r13, rax
    mov rdi, rax
    lea rsi, [rel zone_prefix]
    mov edx, 20
    call memcpy
    lea rdi, [r13 + 20]
    mov rsi, r12
    mov rdx, r14
    call memcpy
    mov rdi, r13
    jmp .read
.system_path:
    lea rdi, [rel system_zone]
    jmp .read
.absolute:
    mov rdi, r12
.read:
    call __al_tzif_read
    test rax, rax
    jnz .read_complete
    test r13, r13
    jz .read_complete
    mov rdi, r13
    lea rsi, [rel nix_zone_prefix]
    mov edx, 14
    call memcpy
    lea rdi, [r13 + 14]
    mov rsi, r12
    mov rdx, r14
    call memcpy
    mov rdi, r13
    call __al_tzif_read
.read_complete:
    mov r14, rdx
    mov r15, rax
    mov rdi, r13
    call free
    test r15, r15
    jz .free_zone
    mov [rbx], r15
    mov [rbx + 8], r14
    mov rdi, r15
    mov rsi, r14
    mov rdx, rbx
    call __al_tzif_parse
    test eax, eax
    jnz .free_file
    mov rdi, rbx
    call __al_tzif_leaps
    test eax, eax
    jnz .free_file
    mov rdi, [rbx + 48]
    test rdi, rdi
    jz .success
    mov rsi, rbx
    mov edx, 24
    cmp qword [rbx + 96], 50      ; version 2 has no extended hours
    je .footer
    mov edx, 167
.footer:
    call __al_tz_rule_parse
    test eax, eax
    jz .success
.free_file:
    mov rdi, r15
    call free
.free_zone:
    mov rdi, rbx
    call free
.fallback:
    xor eax, eax
    jmp .done
.success:
    mov rax, rbx
.done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.__al_zone_load alloc noexec nowrite progbits
system_zone: db "/etc/localtime", 0
zone_prefix: db "/usr/share/zoneinfo/"
nix_zone_prefix: db "/etc/zoneinfo/"

section .note.GNU-stack noalloc noexec nowrite progbits
