; Original TZ rule date parser. Inputs: cursor, 48-byte rule record, and
; maximum transition hour. Return next cursor or null.
bits 64
default rel

global __al_tz_date_rule:function
extern __al_tz_uint:function
extern __al_tz_value:function

section .text.__al_tz_date_rule alloc exec nowrite progbits
__al_tz_date_rule:
    push rbx
    push r12
    push r13
    mov rbx, rsi
    mov r12, rdx
    mov qword [rbx], 0           ; numeric year day
    mov qword [rbx + 32], 7200   ; default local transition time
    mov qword [rbx + 40], 0      ; wall clock time
    movzx eax, byte [rdi]
    cmp eax, 77                  ; M
    je .month
    cmp eax, 74                  ; J
    jne .year_day
    mov qword [rbx], 1           ; Julian day omitting February 29
    inc rdi
.year_day:
    mov esi, 365
    call __al_tz_uint
    test rax, rax
    jz .done
    cmp qword [rbx], 1
    jne .publish_day
    test edx, edx
    jz .invalid
.publish_day:
    mov [rbx + 8], rdx
    jmp .time
.month:
    mov qword [rbx], 2
    inc rdi
    mov esi, 12
    call __al_tz_uint
    test rax, rax
    jz .done
    test edx, edx
    jz .invalid
    dec rdx
    mov [rbx + 8], rdx           ; zero-based month
    cmp byte [rax], 46
    jne .invalid
    lea rdi, [rax + 1]
    mov esi, 5
    call __al_tz_uint
    test rax, rax
    jz .done
    test edx, edx
    jz .invalid
    mov [rbx + 16], rdx
    cmp byte [rax], 46
    jne .invalid
    lea rdi, [rax + 1]
    mov esi, 6
    call __al_tz_uint
    test rax, rax
    jz .done
    mov [rbx + 24], rdx
.time:
    cmp byte [rax], 47           ; /
    jne .done
    lea rdi, [rax + 1]
    mov rsi, r12
    cmp esi, 24
    jne .extended_time
    movzx r13d, byte [rdi]
    cmp r13d, 43
    je .invalid
    cmp r13d, 45
    je .invalid
.extended_time:
    call __al_tz_value
    test rax, rax
    jz .done
    mov [rbx + 32], rdx
    movzx edx, byte [rax]
    cmp edx, 119                 ; w
    je .advance
    cmp edx, 115                 ; s
    je .standard
    cmp edx, 117                 ; u
    je .utc
    cmp edx, 103                 ; g
    je .utc
    cmp edx, 122                 ; z
    jne .done
.utc:
    mov qword [rbx + 40], 2
    jmp .advance
.standard:
    mov qword [rbx + 40], 1
.advance:
    inc rax
    jmp .done
.invalid:
    xor eax, eax
.done:
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
