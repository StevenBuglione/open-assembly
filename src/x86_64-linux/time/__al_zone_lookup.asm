; Original zone selection. Inputs: validated zone or null, POSIX timestamp.
; Outputs: UTC offset, designation, DST in RAX/RDX/RCX.
bits 64
default rel

global __al_zone_lookup:function
extern __al_tzif_scale:function
extern __al_tzif_type:function
extern __al_tz_rule_lookup:function

section .text.__al_zone_lookup alloc exec nowrite progbits
__al_zone_lookup:
    test rdi, rdi
    jz .utc
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi
    call __al_tzif_scale
    mov rdi, rbx
    mov rsi, rax
    call __al_tzif_type
    test edx, edx
    jnz .rule
    mov rsi, [rbx + 32]
    imul rax, 6
    add rsi, rax
    mov eax, [rsi]
    bswap eax
    movsxd rax, eax
    movzx ecx, byte [rsi + 4]
    movzx edx, byte [rsi + 5]
    add rdx, [rbx + 40]
    jmp .done
.rule:
    mov rdi, rbx
    mov rsi, r12
    call __al_tz_rule_lookup
.done:
    add rsp, 8
    pop r12
    pop rbx
    ret
.utc:
    xor eax, eax
    lea rdx, [rel utc]
    xor ecx, ecx
    ret

section .rodata.__al_zone_lookup alloc noexec nowrite progbits
utc: db "UTC", 0

section .note.GNU-stack noalloc noexec nowrite progbits
