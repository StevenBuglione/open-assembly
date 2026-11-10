; Encode and write one wide character with the wide stream already locked.
bits 64
default rel

global __al_stream_putwc:function
extern __al_mb_encode:function
extern __al_stream_write_raw:function

section .text.__al_stream_putwc alloc exec nowrite progbits
__al_stream_putwc:
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rdi
    mov r12d, esi
    lea rdi, [rbx + 152]
    lea rdx, [rbx + 136]
    mov ecx, [rbx + 132]
    inc ecx                     ; explicit C or UTF-8 encoding
    call __al_mb_encode
    test rax, rax
    js .encoding_error
    mov rdi, rbx
    lea rsi, [rbx + 152]
    mov rdx, rax
    call __al_stream_write_raw
    test edx, edx
    jnz .failure
    mov eax, r12d
    jmp .return
.encoding_error:
    or qword [rbx + 8], 32
.failure:
    mov eax, -1
.return:
    add rsp, 8
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
