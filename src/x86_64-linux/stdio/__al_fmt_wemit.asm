; Emit counted units to a wide buffer or locked wide stream. A null source
; repeats ECX. R8 selects one-byte ASCII or four-byte wide source units.
bits 64
default rel

global __al_fmt_wemit:function
extern __al_stream_putwc:function
extern __al_stdio_errno:function

section .text.__al_fmt_wemit alloc exec nowrite progbits
__al_fmt_wemit:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r15, r8
    mov [rsp], ecx
    mov dword [rsp + 4], 0     ; truncated bounded output
    test r13, r13
    jz .success
    mov r14, [rbx + 16]
    add r14, r13
    jc .overflow
    cmp r14, 2147483647
    ja .overflow
    cmp qword [rbx + 24], 3
    jne .next
    mov rax, [rbx + 16]
    cmp r14, [rbx + 8]
    jbe .buffer_cursor
    mov r14, [rbx + 8]
    mov r13, r14
    sub r13, rax
    jz .failure
    mov dword [rsp + 4], 1     ; commit the prefix before reporting overflow
.buffer_cursor:
    mov rdx, [rbx]
    lea rax, [rdx + rax * 4]
    mov [rsp + 8], rax
.next:
    mov esi, [rsp]
    test r12, r12
    jz .store
    cmp r15d, 4
    je .wide_source
    movzx esi, byte [r12]
    jmp .advance_source
.wide_source:
    mov esi, [r12]
.advance_source:
    add r12, r15
.store:
    cmp qword [rbx + 24], 3
    jne .stream
    mov rax, [rsp + 8]
    mov [rax], esi
    add qword [rsp + 8], 4
    jmp .count
.stream:
    mov rdi, [rbx]
    call __al_stream_putwc
    cmp eax, -1
    je .failure
.count:
    dec r13
    jnz .next
    mov [rbx + 16], r14
    cmp dword [rsp + 4], 0
    jne .failure
.success:
    xor eax, eax
    jmp .return
.overflow:
    mov edi, 75                 ; EOVERFLOW
    call __al_stdio_errno
.failure:
    mov eax, -1
.return:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
