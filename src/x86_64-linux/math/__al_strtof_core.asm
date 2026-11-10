; Original floating conversion dispatcher. rdi = string, rsi = endptr,
; rdx = target 0 binary32, 1 binary64, 2 x86 extended. Bit 2 selects wide input.
; Returns raw bits in rax and extended sign/exponent in dx.
bits 64
default rel

global __al_strtof_core:function
extern __al_fork_scratch_locks:data
extern __al_lock:function
extern __al_unlock:function
extern __al_float_lex:function
extern __al_float_round:function
extern __errno_location:function
extern feraiseexcept:function

section .text.__al_strtof_core alloc exec nowrite progbits
__al_strtof_core:
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
    lea rdi, [rel __al_fork_scratch_locks + 60]
    call __al_lock
    mov rdi, rbx
    lea rsi, [rel numerator]
    lea rdx, [rel metadata]
    mov ecx, 1
    test r13d, 4
    jz .lex
    mov ecx, 4
    and r13d, 3
.lex:
    call __al_float_lex
    test r12, r12
    jz .kind
    mov rcx, [rel metadata]
    mov [r12], rcx
.kind:
    mov qword [rsp], 0
    cmp rax, 1
    je .finite
    ja .special
    xor eax, eax
    xor edx, edx
    jmp .pack
.special:
    cmp rax, -1
    je .absent
    mov ecx, 23
    mov edx, 255
    test r13, r13
    jz .special_bits
    mov ecx, 52
    mov edx, 2047
    cmp r13, 1
    je .special_bits
    mov ecx, 63
    mov edx, 32767
.special_bits:
    mov r8d, 1
    shl r8, cl
    cmp eax, 2
    je .infinity
    mov rax, r8
    shr rax, 1                   ; quiet NaN payload bit
    or rax, r8
    jmp .pack
.infinity:
    mov rax, r8
    jmp .pack
.absent:
    mov qword [rel metadata + 8], 0
    xor eax, eax
    xor edx, edx
    jmp .pack
.finite:
    lea rdi, [rel numerator]
    lea rsi, [rel denominator]
    lea rdx, [rel comparison]
    lea rcx, [rel metadata]
    mov r8, r13
    call __al_float_round
    mov [rsp], rcx
.pack:
    mov r8, [rel metadata + 8]
    test r13, r13
    jz .binary32
    cmp r13, 1
    je .binary64
    shl r8d, 15
    or edx, r8d
    jmp .save
.binary32:
    and eax, 0x7fffff
    shl edx, 23
    shl r8d, 31
    or eax, edx
    or eax, r8d
    jmp .save
.binary64:
    shl rax, 12
    shr rax, 12
    shl rdx, 52
    shl r8, 63
    or rax, rdx
    or rax, r8
.save:
    mov r14, rax
    mov r15, rdx
    lea rdi, [rel __al_fork_scratch_locks + 60]
    call __al_unlock
    test qword [rsp], 24          ; overflow or underflow
    jz .exceptions
    call __errno_location
    mov dword [rax], 34           ; ERANGE
.exceptions:
    mov edi, [rsp]
    test edi, edi
    jz .return_bits
    call feraiseexcept
.return_bits:
    mov rax, r14
    mov rdx, r15
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .bss.__al_strtof_core alloc noexec write nobits align=8
    resq 1                    ; preserve scratch record offsets
metadata:
    resq 6
numerator:
    resq 1281
denominator:
    resq 1281
comparison:
    resq 1281

section .note.GNU-stack noalloc noexec nowrite progbits
