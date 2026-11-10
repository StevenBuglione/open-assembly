; Original formatted output sink. rdi = context, rsi = bytes or NULL,
; rdx = count, rcx = fill byte for NULL source. Returns 0 or -1.
bits 64
default rel

global __al_fmt_emit:function
extern __al_stream_write:function
extern __al_fmt_wemit:function
extern __al_stdio_errno:function
extern memcpy:function
extern memset:function
extern realloc:function

section .text.__al_fmt_emit alloc exec nowrite progbits
__al_fmt_emit:
    cmp qword [rdi + 24], 3
    jb .byte_sink
    mov r8d, 1                  ; widen ASCII source and padding
    sub rsp, 8
    call __al_fmt_wemit
    add rsp, 8
    ret
.byte_sink:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r15, rcx
    test r13, r13
    jz .success
    mov r14, [rbx + 16]           ; previous untruncated count
    add r14, r13
    jc .overflow
    cmp r14, 2147483647
    ja .overflow
    cmp qword [rbx + 24], 2
    je .dynamic
    cmp qword [rbx + 24], 0
    jne .stream

    mov rax, [rbx + 16]
    mov rdx, [rbx + 8]            ; capacity excluding the final NUL
    cmp rax, rdx
    jae .commit
    sub rdx, rax
    cmp rdx, r13
    jbe .string_chunk
    mov rdx, r13
.string_chunk:
    mov rdi, [rbx]
    add rdi, rax
    test r12, r12
    jz .string_fill
    mov rsi, r12
    call memcpy
    jmp .commit
.string_fill:
    mov rsi, r15
    call memset
    jmp .commit

.dynamic:
    mov rsi, [rbx + 8]
    cmp r14, rsi
    jbe .dynamic_chunk
    lea rsi, [rsi * 2 + 63]       ; grow geometrically, starting at 64 bytes
    cmp rsi, 2147483647
    jbe .required_size
    mov esi, 2147483647
.required_size:
    cmp rsi, r14
    jae .allocate
    mov rsi, r14
.allocate:
    mov [rsp], rsi
    inc rsi                      ; storage for the terminating NUL
    mov rdi, [rbx]
    call realloc
    test rax, rax
    jz .failure
    mov [rbx], rax
    mov rdx, [rsp]
    mov [rbx + 8], rdx
.dynamic_chunk:
    mov rax, [rbx + 16]
    mov rdx, r13
    jmp .string_chunk

.stream:
    test r12, r12
    jz .prepare_fill
    mov rdi, [rbx]
    mov rsi, r12
    mov rdx, r13
    call __al_stream_write
    test rdx, rdx
    jnz .failure
    jmp .commit
.prepare_fill:
    lea rdi, [rbx + 64]
    mov rsi, r15
    mov edx, 64
    call memset
.stream_fill:
    mov r12, r13
    cmp r12, 64
    jbe .write_chunk
    mov r12d, 64
.write_chunk:
    mov rdi, [rbx]
    lea rsi, [rbx + 64]
    mov rdx, r12
    call __al_stream_write
    test rdx, rdx
    jnz .failure
    sub r13, r12
    jnz .stream_fill
.commit:
    mov [rbx + 16], r14
.success:
    xor eax, eax
    jmp .done
.overflow:
    mov edi, 75                   ; EOVERFLOW
    call __al_stdio_errno
.failure:
    mov eax, -1
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
