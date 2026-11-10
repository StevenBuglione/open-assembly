; Original scanner lookahead. rdi = source context. Returns a code unit or -1.
bits 64
default rel

global __al_scan_peek:function
extern __al_stream_read:function
extern __al_stream_getwc:function

section .text.__al_scan_peek alloc exec nowrite progbits
__al_scan_peek:
    mov rax, [rdi + 24]
    cmp rax, -2
    jne .done
    cmp qword [rdi + 8], 0
    je .byte_string
    cmp qword [rdi + 8], 2
    jne .file
    mov rax, [rdi]
    mov eax, [rax]
    jmp .string_unit
.byte_string:
    mov rax, [rdi]
    movzx eax, byte [rax]
.string_unit:
    test eax, eax
    jnz .remember
    mov rax, -1
.remember:
    mov [rdi + 24], rax
.done:
    ret
.file:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8
    mov rbx, rdi
    mov rdi, [rbx]
    cmp qword [rbx + 8], 3
    je .wide_stream
    lea rsi, [rbx + 32]
    mov edx, 1
    call __al_stream_read
    mov [rbx + 48], edx          ; byte read failure vs EOF
    test rax, rax
    jz .end
    movzx eax, byte [rbx + 32]
    jmp .cache
.wide_stream:
    call __al_stream_getwc
    cmp eax, -1
    je .end
    mov [rbx + 48], ecx          ; physical bytes in the decoded lookahead
    mov [rbx + 52], r9d          ; character came from public ungetwc
    mov [rbx + 56], r8           ; decoder state before those bytes
    jmp .cache
.end:
    mov rax, -1
.cache:
    mov [rbx + 24], rax
    add rsp, 8
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
