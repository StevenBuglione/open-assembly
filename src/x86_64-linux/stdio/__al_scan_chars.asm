; Original byte and scanset parser. rdi = input, rsi = output or NULL,
; RDX is byte width, RCX is character (0), string (1) or set (2), R8 is the
; byte set table, and R9D selects wide decoding. EAX is success (0), matching
; failure (1) or input failure (2). On success RDX is destination bytes used.
bits 64
default rel

global __al_scan_chars:function
extern __al_scan_peek:function
extern __al_scan_take:function
extern isspace:function
extern __al_locale_flags:data
extern __al_mb_decode:function
extern __al_stdio_errno:function

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
    mov qword [rbx + 40], 0       ; initial multibyte state
    mov [rsp + 16], r9d
    mov [rsp + 8], r12           ; initial destination
    mov eax, [rel __al_locale_flags]
    and eax, 1
    inc eax
    mov [rsp + 20], eax
.next:
    mov rdi, rbx
    call __al_scan_peek
    test rax, rax
    js .end_input
    mov [rbx + 32], al
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
    inc qword [rsp]
    mov rdi, rbx
    call __al_scan_take
    cmp dword [rsp + 16], 0
    jne .decode
    test r12, r12
    jz .advance
    mov al, [rbx + 32]
    mov [r12], al
    inc r12
    jmp .advance
.decode:
    lea rdi, [rbx + 32]
    mov esi, 1
    lea rdx, [rbx + 40]
    mov ecx, [rsp + 20]
    call __al_mb_decode
    cmp rax, -2
    je .advance
    test rax, rax
    js .input_failure
    test r12, r12
    jz .advance
    mov [r12], edx
    add r12, 4
.advance:
    dec r13
    jnz .next
    jmp .success
.end_input:
    cmp dword [rbx + 44], 0
    je .check_width
    cmp dword [rbx + 48], 0
    jne .input_failure            ; retain descriptor read errno
    jmp .encoding_failure
.check_width:
    test r14, r14
    jz .input_failure             ; %c requires its entire width
    cmp qword [rsp], 0
    jne .success
    jmp .input_failure
.encoding_failure:
    mov edi, 84                   ; EILSEQ, field ends mid-character
    call __al_stdio_errno
.input_failure:
    mov eax, 2
    jmp .done
.end_match:
    cmp qword [rsp], 0
    jne .success
    mov eax, 1
    jmp .done
.success:
    cmp dword [rbx + 44], 0
    jne .encoding_failure
    test r14, r14
    jz .matched
    test r12, r12
    jz .matched
    cmp dword [rsp + 16], 0
    je .byte_nul
    mov dword [r12], 0
    jmp .matched
.byte_nul:
    mov byte [r12], 0
.matched:
    mov rdx, r12
    sub rdx, [rsp + 8]
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
