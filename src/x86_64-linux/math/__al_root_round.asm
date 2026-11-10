; Round root of bignum rdi times 2^rsi, kind edx, sign ecx, degree r8. r9 is 64 bytes of scratch.
bits 64
default rel

global __al_root_round:function
extern fegetround:function
extern __al_big_bits:function
extern __al_big_left:function
extern __al_big_right_sticky:function
extern __al_pow_u65:function
extern __al_u256_cmp:function
extern __al_fp_pack_exact:function
extern __al_fp_special:function

section .text.__al_root_round alloc exec nowrite progbits
__al_root_round:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 64
    mov ebx, edx
    mov r12, rdi
    mov r13, r9
    mov [rsp], rsi
    mov [rsp + 8], r8
    mov [rsp + 16], ecx
    call fegetround
    mov [rsp + 20], eax

    mov ecx, 24
    mov edx, -126
    mov r8d, 127
    test ebx, ebx
    jz .format
    mov ecx, 53
    mov edx, -1022
    mov r8d, 1023
    cmp ebx, 1
    je .format
    mov ecx, 64
    mov edx, -16382
    mov r8d, 16383
.format:
    mov [rsp + 24], ecx
    mov [rsp + 28], edx
    mov [rsp + 32], r8d
    mov rdi, r12
    call __al_big_bits
    add rax, [rsp]
    dec rax                      ; unbiased leading exponent of the radicand
    mov r9, [rsp + 8]
    test rax, rax
    jns .positive_exponent
    neg rax
    lea rax, [rax + r9 - 1]
    xor edx, edx
    div r9
    neg rax
    jmp .root_exponent
.positive_exponent:
    xor edx, edx
    div r9
.root_exponent:
    cmp eax, [rsp + 32]
    jg .overflow
    cmp eax, [rsp + 28]
    jge .quantum
    mov eax, [rsp + 28]
.quantum:
    sub eax, [rsp + 24]
    inc eax
    mov [rsp + 36], eax
    movsxd rax, eax
    imul rax, r9
    mov rsi, [rsp]
    sub rsi, rax
    add rsi, r9                  ; retain a degree-bit fractional field
    mov rdi, r12
    xor r14d, r14d
    test rsi, rsi
    js .shift_right
    call __al_big_left
    jmp .retained
.shift_right:
    neg rsi
    call __al_big_right_sticky
    mov r14d, eax
.retained:
    mov [rsp + 40], r14d
    mov qword [r13], 0
    mov qword [r13 + 8], 0
    mov qword [r13 + 16], 0
    mov qword [r13 + 24], 0
    mov r10, [r12]
    xor ecx, ecx
.copy:
    cmp rcx, r10
    je .search
    mov eax, [r12 + rcx*4 + 8]
    mov [r13 + rcx*4], eax
    inc rcx
    jmp .copy

.search:
    xor r14d, r14d
    mov ecx, [rsp + 24]
    dec ecx
    mov r15d, 1
    shl r15, cl
.trial:
    lea rsi, [r14 + r15]
    lea rdi, [r13 + 32]
    xor edx, edx
    add rsi, rsi
    adc edx, 0
    mov ecx, [rsp + 8]
    call __al_pow_u65
    mov rdi, r13
    lea rsi, [r13 + 32]
    call __al_u256_cmp
    test eax, eax
    js .next_bit
    or r14, r15
.next_bit:
    shr r15, 1
    jnz .trial

    mov rsi, r14
    lea rdi, [r13 + 32]
    xor edx, edx
    add rsi, rsi
    adc edx, 0
    mov ecx, [rsp + 8]
    call __al_pow_u65
    mov rdi, r13
    lea rsi, [r13 + 32]
    call __al_u256_cmp
    mov dword [rsp + 44], 0
    test eax, eax
    jnz .inexact
    cmp dword [rsp + 40], 0
    je .range
.inexact:
    mov dword [rsp + 44], 32
    mov eax, [rsp + 20]
    test eax, eax
    jz .nearest
    cmp eax, 1024
    je .downward
    cmp eax, 2048
    jne .range
    cmp dword [rsp + 16], 0
    je .increment
    jmp .range
.downward:
    cmp dword [rsp + 16], 0
    jne .increment
    jmp .range
.nearest:
    mov rsi, r14
    lea rdi, [r13 + 32]
    xor edx, edx
    add rsi, rsi
    adc edx, 0
    inc rsi
    mov ecx, [rsp + 8]
    call __al_pow_u65
    mov rdi, r13
    lea rsi, [r13 + 32]
    call __al_u256_cmp
    test eax, eax
    jg .increment
    jl .range
    cmp dword [rsp + 40], 0
    jne .increment
    test r14b, 1
    jz .range
.increment:
    mov ecx, [rsp + 24]
    dec ecx
    add r14, 1
    jc .normalize_carry
    bsr rax, r14
    cmp eax, ecx
    jbe .range
.normalize_carry:
    mov r14d, 1
    shl r14, cl
    inc dword [rsp + 36]
.range:
    test r14, r14
    jz .tiny
    bsr rax, r14
    add eax, [rsp + 36]
    cmp eax, [rsp + 32]
    jg .overflow
    cmp eax, [rsp + 28]
    jge .pack
.tiny:
    cmp dword [rsp + 44], 0
    je .pack
    or dword [rsp + 44], 16
.pack:
    mov edi, ebx
    mov rsi, r14
    mov edx, [rsp + 36]
    mov ecx, [rsp + 16]
    call __al_fp_pack_exact
    mov ecx, [rsp + 44]
    jmp .done
.overflow:
    xor esi, esi
    mov eax, [rsp + 20]
    test eax, eax
    jz .overflow_pack
    mov esi, 1
    cmp eax, 3072
    je .overflow_pack
    cmp dword [rsp + 16], 0
    je .positive_overflow
    cmp eax, 1024
    jne .overflow_pack
    xor esi, esi
    jmp .overflow_pack
.positive_overflow:
    cmp eax, 2048
    jne .overflow_pack
    xor esi, esi
.overflow_pack:
    mov edi, ebx
    mov edx, [rsp + 16]
    call __al_fp_special
    mov ecx, 40
.done:
    add rsp, 64
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
