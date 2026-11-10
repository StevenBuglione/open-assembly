; Original signed h[:mm[:ss]] parser. Inputs: cursor, max hour.
; Outputs: next cursor and signed seconds, or null.
bits 64
default rel

global __al_tz_value:function
extern __al_tz_uint:function

section .text.__al_tz_value alloc exec nowrite progbits
__al_tz_value:
    push rbx
    push r12
    push r13
    xor r13d, r13d
    cmp byte [rdi], 45
    jne .positive
    mov r13d, 1
    jmp .sign
.positive:
    cmp byte [rdi], 43
    jne .hours
.sign:
    inc rdi
.hours:
    mov rbx, rdi
    call __al_tz_uint
    test rax, rax
    jz .done
    sub rbx, rax
    cmp rbx, -3
    jl .invalid
    mov r12, rdx
    imul r12, 3600
    cmp byte [rax], 58
    jne .signed
    lea rbx, [rax + 1]
    mov rdi, rbx
    mov esi, 59
    call __al_tz_uint
    test rax, rax
    jz .done
    add rbx, 2
    cmp rax, rbx
    jne .invalid
    imul rdx, 60
    add r12, rdx
    cmp byte [rax], 58
    jne .signed
    lea rbx, [rax + 1]
    mov rdi, rbx
    mov esi, 59
    call __al_tz_uint
    test rax, rax
    jz .done
    add rbx, 2
    cmp rax, rbx
    jne .invalid
    add r12, rdx
.signed:
    mov rdx, r12
    test r13d, r13d
    jz .done
    neg rdx
    jmp .done
.invalid:
    xor eax, eax
.done:
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
