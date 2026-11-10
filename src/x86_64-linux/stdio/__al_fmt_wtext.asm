; Render a wide printf c or s conversion, with width and precision in units.
bits 64
default rel

global __al_fmt_wtext:function
extern __al_fmt_emit:function
extern __al_fmt_wemit:function
extern __al_mb_decode:function
extern __al_locale_flags:data
extern __al_stdio_errno:function

section .text.__al_fmt_wtext alloc exec nowrite progbits
__al_fmt_wtext:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32
    mov rbx, rdi                ; output context
    mov r12, rsi                ; format fields
    mov r13, rdx                ; string pointer or scalar
    xor r14d, r14d              ; result length in wide units
    cmp qword [r12 + 32], 99
    jne .string
    mov r14d, 1
    mov dword [rsp], 2          ; single wide character
    cmp qword [r12 + 24], 8
    je .padding
    cmp qword [r12 + 24], 4
    jne .invalid
    and r13d, 255               ; %c converts the low byte with btowc semantics
    cmp r13d, 127
    ja .encoding_error
    jmp .padding
.string:
    cmp qword [r12 + 24], 8
    je .wide_string
    cmp qword [r12 + 24], 4
    jne .invalid
    mov dword [rsp], 1          ; multibyte source
    test r13, r13
    jnz .measure_mb
    lea r13, [rel null_mb]
.measure_mb:
    mov [rsp + 16], r13
    mov qword [rbx + 48], 0     ; initial conversion state
    mov eax, [rel __al_locale_flags]
    and eax, 1
    inc eax
    mov [rsp + 24], eax         ; use the same encoding on both passes
.mb_count:
    cmp r14, [r12 + 16]
    jae .padding
    mov rdi, [rsp + 16]
    mov esi, 4
    lea rdx, [rbx + 48]
    mov ecx, [rsp + 24]
    call __al_mb_decode
    test rax, rax
    jz .padding
    js .encoding_error
    add [rsp + 16], rax
    inc r14
    jmp .mb_count
.wide_string:
    mov dword [rsp], 0
    test r13, r13
    jnz .wide_count
    lea r13, [rel null_wide]
.wide_count:
    cmp r14, [r12 + 16]
    jae .padding
    cmp dword [r13 + r14 * 4], 0
    je .padding
    inc r14
    jmp .wide_count
.padding:
    xor r15d, r15d
    mov rax, [r12 + 8]
    cmp rax, r14
    jbe .body
    sub rax, r14
    mov r15, rax
    test qword [r12], 1
    jnz .body
    mov rdi, rbx
    xor esi, esi
    mov rdx, r15
    mov ecx, 32
    call __al_fmt_emit
    test eax, eax
    jnz .return
.body:
    cmp dword [rsp], 1
    je .multibyte_body
    mov rdi, rbx
    mov rsi, r13
    mov rdx, r14
    xor ecx, ecx
    cmp dword [rsp], 0
    je .emit_wide
    xor esi, esi
    mov ecx, r13d              ; single wide character
.emit_wide:
    mov r8d, 4
    call __al_fmt_wemit
    test eax, eax
    jnz .return
    jmp .trailing
.multibyte_body:
    mov [rsp + 8], r14
    mov [rsp + 16], r13
    mov qword [rbx + 48], 0
.convert:
    cmp qword [rsp + 8], 0
    je .trailing
    mov rdi, [rsp + 16]
    mov esi, 4
    lea rdx, [rbx + 48]
    mov ecx, [rsp + 24]
    call __al_mb_decode
    test rax, rax
    jle .encoding_error
    add [rsp + 16], rax
    mov rdi, rbx
    xor esi, esi
    mov ecx, edx
    mov edx, 1
    mov r8d, 4
    call __al_fmt_wemit
    test eax, eax
    jnz .return
    dec qword [rsp + 8]
    jmp .convert
.trailing:
    xor eax, eax
    test qword [r12], 1
    jz .return
    mov rdi, rbx
    xor esi, esi
    mov rdx, r15
    mov ecx, 32
    call __al_fmt_emit
    jmp .return
.invalid:
    mov edi, 22                 ; EINVAL
    jmp .error
.encoding_error:
    mov edi, 84                 ; EILSEQ
.error:
    call __al_stdio_errno
    mov eax, -1
.return:
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata.__al_fmt_wtext alloc noexec nowrite progbits align=4
null_wide: dd 40, 110, 117, 108, 108, 41, 0
null_mb: db "(null)", 0

section .note.GNU-stack noalloc noexec nowrite progbits
