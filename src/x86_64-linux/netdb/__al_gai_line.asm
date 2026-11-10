; Read one physical line up to 4095 bytes, skipping overlong lines.
; The caller provides a 4096-byte buffer. EOF or error returns null.
bits 64
default rel

global __al_gai_line:function
extern feof:function
extern fgetc:function
extern fgets:function
extern strchr:function

section .text.__al_gai_line alloc exec nowrite progbits
__al_gai_line:
    push r12
    push r13
    sub rsp, 8
    mov r12, rdi                ; stream
    mov r13, rsi                ; line buffer
.read:
    mov rdi, r13
    mov esi, 4096
    mov rdx, r12
    call fgets
    test rax, rax
    jz .return
    mov rdi, r13
    mov esi, 10
    call strchr
    test rax, rax
    jnz .line
    mov rdi, r12
    call fgetc
    test eax, eax
    js .final_line
.discard:
    cmp eax, 10
    je .read
    mov rdi, r12
    call fgetc
    test eax, eax
    jns .discard
    jmp .missing
.final_line:
    mov rdi, r12
    call feof
    test eax, eax
    jz .missing
.line:
    mov rax, r13
    jmp .return
.missing:
    xor eax, eax
.return:
    add rsp, 8
    pop r13
    pop r12
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
