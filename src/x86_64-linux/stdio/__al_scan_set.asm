; Original bracket-set compiler. rdi = format after [, rsi = byte membership table.
bits 64
default rel

global __al_scan_set:function
extern memset:function

section .text.__al_scan_set alloc exec nowrite progbits
__al_scan_set:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi
    mov r13d, 1
    xor esi, esi
    cmp byte [rbx], 94            ; ^
    jne .initialize
    inc rbx
    xor r13d, r13d
    mov esi, 1
.initialize:
    mov rdi, r12
    mov edx, 256
    call memset
    cmp byte [rbx], 93
    jne .next
    mov [r12 + 93], r13b
    inc rbx
.next:
    movzx eax, byte [rbx]
    test eax, eax
    jz .invalid
    cmp eax, 93
    je .complete
    cmp byte [rbx + 1], 45        ; range separator
    jne .single
    movzx edx, byte [rbx + 2]
    test edx, edx
    jz .single
    cmp edx, 93
    je .single
    cmp eax, edx
    ja .single
.range:
    mov [r12 + rax], r13b
    inc eax
    cmp eax, edx
    jbe .range
    add rbx, 3
    jmp .next
.single:
    mov [r12 + rax], r13b
    inc rbx
    jmp .next
.complete:
    lea rax, [rbx + 1]
    jmp .done
.invalid:
    xor eax, eax
.done:
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
