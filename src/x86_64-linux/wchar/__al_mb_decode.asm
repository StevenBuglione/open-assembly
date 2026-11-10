; Decode at most rsi bytes from rdi using state rdx. Return count and scalar in rax/edx.
bits 64
default rel

global __al_mb_decode:function
extern __al_mb_error:function
extern __al_locale_flags:data

section .text.__al_mb_decode alloc exec nowrite progbits
__al_mb_decode:
    test rsi, rsi
    jz .incomplete_empty
    xor r9d, r9d
    mov r8d, [rdx + 4]
    test r8d, r8d
    jnz .pending
    movzx ecx, byte [rdi]
    mov r9d, 1
    cmp ecx, 0x80
    jb .complete
    test dword [rel __al_locale_flags], 1
    jz .invalid
    cmp ecx, 0xc2
    jb .invalid
    cmp ecx, 0xe0
    jb .two_bytes
    cmp ecx, 0xf0
    jb .three_bytes
    cmp ecx, 0xf4
    ja .invalid
    mov r8d, 0xbf8003
    cmp ecx, 0xf0
    jne .four_upper
    mov r8d, 0xbf9003
.four_upper:
    cmp ecx, 0xf4
    jne .four_payload
    mov r8d, 0x8f8003
.four_payload:
    and ecx, 7
    jmp .continuation
.three_bytes:
    mov r8d, 0xbf8002
    cmp ecx, 0xe0
    jne .three_upper
    mov r8d, 0xbfa002
.three_upper:
    cmp ecx, 0xed
    jne .three_payload
    mov r8d, 0x9f8002
.three_payload:
    and ecx, 15
    jmp .continuation
.two_bytes:
    mov r8d, 0xbf8001
    and ecx, 31
    jmp .continuation
.pending:
    test dword [rel __al_locale_flags], 1
    jz .invalid
    test r8d, 0xff000000
    jnz .invalid
    mov ecx, [rdx]
.continuation:
    cmp r9, rsi
    je .save_pending
    movzx r10d, byte [rdi + r9]
    mov r11d, r8d
    shr r11d, 8
    and r11d, 0xff
    cmp r10d, r11d
    jb .invalid
    mov r11d, r8d
    shr r11d, 16
    cmp r10d, r11d
    ja .invalid
    and r10d, 0x3f
    shl ecx, 6
    or ecx, r10d
    inc r9
    dec r8d
    and r8d, 0xff
    jz .complete
    or r8d, 0xbf8000
    jmp .continuation
.save_pending:
    mov [rdx], ecx
    mov [rdx + 4], r8d
.incomplete_empty:
    mov rax, -2
    ret
.complete:
    mov qword [rdx], 0
    mov edx, ecx
    xor eax, eax
    test ecx, ecx
    jz .return
    mov rax, r9
.return:
    ret
.invalid:
    mov rdi, rdx
    sub rsp, 8
    call __al_mb_error
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
