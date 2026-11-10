; Scan wide c, s or bracket input. R9 is the destination unit width.
; Return status in EAX and the bytes written in RDX on success.
bits 64
default rel

global __al_scan_wchars:function
extern __al_scan_peek:function
extern __al_scan_take:function
extern __al_scan_wmember:function
extern __al_mb_encode:function
extern __al_locale_flags:data
extern iswspace:function

section .text.__al_scan_wchars alloc exec nowrite progbits
__al_scan_wchars:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 48
    mov rbx, rdi                ; input context
    mov r12, rsi                ; destination cursor
    mov r13, rdx                ; remaining wide characters
    mov r14, rcx                ; conversion kind
    mov r15, r8                 ; validated set when applicable
    mov qword [rsp], 0          ; accepted wide characters
    mov [rsp + 16], rsi         ; original destination
    mov [rsp + 24], r9          ; destination unit width
    mov qword [rbx + 40], 0     ; initial multibyte state
    mov eax, [rel __al_locale_flags]
    and eax, 1
    inc eax
    mov [rsp + 32], eax         ; active conversion encoding
.next:
    mov rdi, rbx
    call __al_scan_peek
    test rax, rax
    js .end_input
    mov [rsp + 8], eax
    cmp r14, 1
    je .space
    cmp r14, 2
    jne .accept
    mov rdi, r15
    mov esi, eax
    call __al_scan_wmember
    test eax, eax
    jz .end_match
    jmp .accept
.space:
    mov edi, eax
    call iswspace
    test eax, eax
    jnz .end_match
.accept:
    test r12, r12
    jz .consume
    cmp qword [rsp + 24], 4
    je .wide
    mov rdi, r12
    mov esi, [rsp + 8]
    lea rdx, [rbx + 40]
    mov ecx, [rsp + 32]
    call __al_mb_encode
    test rax, rax
    js .input_failure
    add r12, rax
    jmp .consume
.wide:
    mov eax, [rsp + 8]
    mov [r12], eax
    add r12, 4
.consume:
    inc qword [rsp]
    mov rdi, rbx
    call __al_scan_take
    dec r13
    jnz .next
    jmp .success
.end_input:
    test r14, r14
    jz .input_failure           ; c requires its entire width
    cmp qword [rsp], 0
    jne .success
.input_failure:
    mov eax, 2
    jmp .return
.end_match:
    cmp qword [rsp], 0
    jne .success
    mov eax, 1
    jmp .return
.success:
    mov rdx, r12
    sub rdx, [rsp + 16]
    test r14, r14
    jz .matched
    test r12, r12
    jz .matched
    cmp qword [rsp + 24], 4
    je .wide_end
    mov byte [r12], 0
    jmp .matched
.wide_end:
    mov dword [r12], 0
.matched:
    xor eax, eax
.return:
    add rsp, 48
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
