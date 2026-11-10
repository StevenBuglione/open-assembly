; Original numeric scanf item parser. rdi = input, rsi = width, rdx = base.
; rax = value bits, rdx = 0 success, 1 matching failure, 2 input failure.
bits 64
default rel

global __al_scan_number:function
extern __al_scan_peek:function
extern __al_scan_take:function

section .text.__al_scan_number alloc exec nowrite progbits
__al_scan_number:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi                  ; remaining width
    mov r13, rdx                  ; radix, zero for %i
    xor r14d, r14d                ; valid digit seen
    xor r15d, r15d                ; accumulated bits
    mov qword [rsp], 0           ; minus sign
    call __al_scan_peek
    test rax, rax
    js .input_failure
    cmp eax, 45
    jne .plus
    mov qword [rsp], 1
    jmp .sign
.plus:
    cmp eax, 43
    jne .radix
.sign:
    mov rdi, rbx
    call __al_scan_take
    dec r12
    jz .matching_failure
    mov rdi, rbx
    call __al_scan_peek
    test rax, rax
    js .matching_failure

.radix:
    cmp eax, 48
    jne .decimal_default
    test r13, r13
    jz .octal_default
    cmp r13, 16
    jne .next
    jmp .leading_zero
.octal_default:
    mov r13d, 8
.leading_zero:
    mov rdi, rbx
    call __al_scan_take
    mov r14d, 1
    dec r12
    jz .result
    mov rdi, rbx
    call __al_scan_peek
    or eax, 32
    cmp eax, 120                  ; x or X after the leading zero
    jne .next
    mov rdi, rbx
    call __al_scan_take
    mov r13d, 16
    xor r14d, r14d                ; a consumed prefix alone does not match
    dec r12
    jz .matching_failure
    jmp .next
.decimal_default:
    test r13, r13
    jnz .next
    mov r13d, 10

.next:
    mov rdi, rbx
    call __al_scan_peek
    test rax, rax
    js .result
    lea rcx, [rax - 48]
    cmp rcx, 9
    jbe .check_radix
    or eax, 32
    lea rcx, [rax - 87]
    cmp rcx, 10
    jb .result
    cmp rcx, 15
    ja .result
.check_radix:
    cmp rcx, r13
    jae .result
    imul r15, r13
    add r15, rcx
    mov r14d, 1
    mov rdi, rbx
    call __al_scan_take
    dec r12
    jnz .next
.result:
    test r14d, r14d
    jz .matching_failure
    mov rax, r15
    cmp qword [rsp], 0
    je .success
    neg rax
.success:
    xor edx, edx
    jmp .done
.matching_failure:
    mov edx, 1
    jmp .done
.input_failure:
    mov edx, 2
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
