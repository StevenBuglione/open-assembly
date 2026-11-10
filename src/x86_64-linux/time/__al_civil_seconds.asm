; Original unzoned normalization of the signed 32-bit tm input fields.
; The largest normalized year and all second adjustments fit int64_t.
bits 64
default rel

global __al_civil_seconds:function
extern __al_gregorian_day:function

section .text.__al_civil_seconds alloc exec nowrite progbits
__al_civil_seconds:
    push rbx
    mov rbx, rdi
    movsxd rax, dword [rbx + 16]
    cqo
    mov ecx, 12
    idiv rcx
    test rdx, rdx
    jns .month
    add rdx, 12
    dec rax
.month:
    mov rsi, rdx
    movsxd rdi, dword [rbx + 20]
    lea rdi, [rdi + rax + 1900]
    movsxd rdx, dword [rbx + 12]
    call __al_gregorian_day
    imul rax, 86400
    movsxd rdx, dword [rbx + 8]
    imul rdx, 3600
    add rax, rdx
    movsxd rdx, dword [rbx + 4]
    imul rdx, 60
    add rax, rdx
    movsxd rdx, dword [rbx]
    add rax, rdx
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
