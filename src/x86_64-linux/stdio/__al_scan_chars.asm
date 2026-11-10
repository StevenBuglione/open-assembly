; Original byte and scanset parser. rdi = input, rsi = output or NULL,
; rdx = width, rcx = 0 character / 1 string / 2 set, r8 = set table.
; eax = 0 success, 1 matching failure, 2 input failure.
bits 64
default rel

global __al_scan_chars:function
extern __al_scan_peek:function
extern __al_scan_take:function
extern isspace:function

section .text.__al_scan_chars alloc exec nowrite progbits
__al_scan_chars:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 24
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov r15, r8
    mov qword [rsp], 0            ; accepted bytes
.next:
    mov rdi, rbx
    call __al_scan_peek
    test rax, rax
    js .end_input
    mov [rsp + 8], rax
    cmp r14, 1
    je .string
    cmp r14, 2
    jne .accept
    cmp byte [r15 + rax], 0
    je .end_match
    jmp .accept
.string:
    mov edi, eax
    call isspace
    test eax, eax
    jnz .end_match
.accept:
    test r12, r12
    jz .consume
    mov al, [rsp + 8]
    mov [r12], al
    inc r12
.consume:
    inc qword [rsp]
    mov rdi, rbx
    call __al_scan_take
    dec r13
    jnz .next
    jmp .success
.end_input:
    test r14, r14
    jz .input_failure             ; %c requires its entire width
    cmp qword [rsp], 0
    jne .success
.input_failure:
    mov eax, 2
    jmp .done
.end_match:
    cmp qword [rsp], 0
    jne .success
    mov eax, 1
    jmp .done
.success:
    test r14, r14
    jz .matched
    test r12, r12
    jz .matched
    mov byte [r12], 0
.matched:
    xor eax, eax
.done:
    add rsp, 24
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
