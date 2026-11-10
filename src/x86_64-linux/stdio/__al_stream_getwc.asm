; Read one wide character with the stream locked. EDX distinguishes error from EOF.
; Successful reads also return the physical byte count in ECX, prior decoder state
; in R8, and whether the character came from public pushback in R9D.
bits 64
default rel

global __al_stream_getwc:function
extern __al_stream_read_raw:function
extern __al_mb_decode:function
extern __al_stdio_errno:function

section .text.__al_stream_getwc alloc exec nowrite progbits
__al_stream_getwc:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    xor r12d, r12d
    mov r13, [rbx + 136]
    mov eax, [rbx + 144]
    cmp eax, -1
    jne .pushback
    mov eax, [rbx + 148]
    cmp eax, -1
    jne .lookahead
.byte:
    mov rdi, rbx
    lea rsi, [rbx + 152]
    mov edx, 1
    call __al_stream_read_raw
    test rax, rax
    jz .no_byte
    inc r12d
    lea rdi, [rbx + 152]
    mov esi, 1
    lea rdx, [rbx + 136]
    mov ecx, [rbx + 132]
    inc ecx                     ; explicit C or UTF-8 encoding
    call __al_mb_decode
    cmp rax, -2
    je .byte
    test rax, rax
    js .encoding_error
    mov eax, edx
    jmp .physical
.pushback:
    mov dword [rbx + 144], -1
    mov r9d, 1
    jmp .success
.lookahead:
    mov r12d, [rbx + 160]
    mov r13, [rbx + 168]
    mov dword [rbx + 148], -1
    mov dword [rbx + 160], 0
.physical:
    xor r9d, r9d
.success:
    xor edx, edx
    mov ecx, r12d
    mov r8, r13
    jmp .return
.no_byte:
    test edx, edx
    jnz .io_error
    cmp dword [rbx + 140], 0
    je .end_of_file
    mov edi, 84                 ; EILSEQ, incomplete character at EOF
    call __al_stdio_errno
    and qword [rbx + 8], -17    ; distinguish an encoding error from EOF
.encoding_error:
    or qword [rbx + 8], 32
    mov qword [rbx + 136], 0
.io_error:
    mov edx, 1
.end_of_file:
    mov eax, -1
.return:
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
