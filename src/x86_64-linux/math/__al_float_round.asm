; Original exact rational rounding.
; rdi = numerator, rsi = denominator scratch, rdx = comparison scratch,
; rcx = metadata, r8 = target 0 binary32 / 1 binary64 / 2 extended.
; Radix zero preserves a supplied denominator. Other modes start from one.
; Returns integer significand in rax, biased exponent in rdx and flags in rcx.
bits 64
default rel

global __al_float_round:function
extern __al_big_muladd:function
extern __al_big_copy:function
extern __al_big_bits:function
extern __al_big_cmp:function
extern __al_big_sub:function
extern __al_big_left:function
extern __al_big_right1:function
extern fegetround:function

section .text.__al_float_round alloc exec nowrite progbits
__al_float_round:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 72
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov rax, [r14 + 16]
    mov [rsp], rax               ; binary power k, also decimal power of five
    lea rax, [rel formats]
    lea rdx, [r8 + r8*2]
    lea rax, [rax + rdx*4]
    mov edx, [rax]
    mov [rsp + 8], rdx           ; precision p
    movsxd rdx, dword [rax + 4]
    mov [rsp + 16], rdx          ; minimum normal exponent
    movsxd rdx, dword [rax + 8]
    mov [rsp + 24], rdx          ; maximum exponent and bias
    call fegetround
    mov [rsp + 32], eax
    mov qword [rsp + 56], 0      ; standard exception flags

    cmp qword [r14 + 24], 0
    je .find_exponent
    mov qword [r12], 1
    mov dword [r12 + 8], 1
    cmp qword [r14 + 24], 10
    jne .find_exponent
    mov rax, [rsp]
    add rax, [r14 + 40]
    dec rax                      ; leading decimal order
    cmp rax, 5000
    jg .overflow
    cmp rax, -5000
    jl .tiny
    mov rax, [rsp]
    test rax, rax
    jz .find_exponent
    js .negative_power
    mov [rsp + 48], rax
.multiply_numerator:
    mov rdi, rbx
    mov esi, 5
    xor edx, edx
    call __al_big_muladd
    dec qword [rsp + 48]
    jnz .multiply_numerator
    jmp .find_exponent
.negative_power:
    neg rax
    mov [rsp + 48], rax
.multiply_denominator:
    mov rdi, r12
    mov esi, 5
    xor edx, edx
    call __al_big_muladd
    dec qword [rsp + 48]
    jnz .multiply_denominator

.find_exponent:
    mov rdi, rbx
    call __al_big_bits
    mov [rsp + 40], rax
    mov rdi, r12
    call __al_big_bits
    sub [rsp + 40], rax          ; tentative floor(log2(N/D))
    js .shift_numerator_for_test
    mov rdi, r13
    mov rsi, r12
    call __al_big_copy
    mov rdi, r13
    mov rsi, [rsp + 40]
    call __al_big_left
    mov rdi, rbx
    mov rsi, r13
    call __al_big_cmp
    jmp .compare_exponent
.shift_numerator_for_test:
    mov rdi, r13
    mov rsi, rbx
    call __al_big_copy
    mov rdi, r13
    mov rsi, [rsp + 40]
    neg rsi
    call __al_big_left
    mov rdi, r13
    mov rsi, r12
    call __al_big_cmp
.compare_exponent:
    test eax, eax
    jns .binary_exponent
    dec qword [rsp + 40]
.binary_exponent:
    mov rax, [rsp + 40]
    add rax, [rsp]
    cmp rax, [rsp + 24]
    jg .overflow
    mov rcx, [rsp + 16]
    sub rcx, [rsp + 8]
    cmp rax, rcx
    jl .tiny                     ; below half of the smallest subnormal
    cmp rax, [rsp + 16]
    jge .quantum
    mov rax, [rsp + 16]          ; use the subnormal quantum
.quantum:
    mov [rsp + 40], rax
    mov rsi, [rsp]
    sub rsi, rax
    add rsi, [rsp + 8]
    dec rsi
    js .scale_denominator
    mov rdi, rbx
    call __al_big_left
    jmp .divide
.scale_denominator:
    neg rsi
    mov rdi, r12
    call __al_big_left

.divide:
    xor r15d, r15d               ; quotient
    mov rdi, rbx
    call __al_big_bits
    mov [rsp + 48], rax
    mov rdi, r12
    call __al_big_bits
    sub [rsp + 48], rax
    js .remainder
    mov rdi, r12
    mov rsi, [rsp + 48]
    call __al_big_left
.quotient_bit:
    shl r15, 1
    mov rdi, rbx
    mov rsi, r12
    call __al_big_cmp
    test eax, eax
    js .next_bit
    mov rdi, rbx
    mov rsi, r12
    call __al_big_sub
    inc r15
.next_bit:
    cmp qword [rsp + 48], 0
    je .remainder
    dec qword [rsp + 48]
    mov rdi, r12
    call __al_big_right1
    jmp .quotient_bit

.remainder:
    cmp qword [rbx], 0
    jne .inexact
    cmp qword [r14 + 32], 0
    je .encode
.inexact:
    mov qword [rsp + 56], 32
    mov eax, [rsp + 32]
    test eax, eax
    jz .nearest
    cmp eax, 1024                ; toward negative infinity
    je .negative_direction
    cmp eax, 2048                ; toward positive infinity
    jne .encode
    cmp qword [r14 + 8], 0
    je .increment
    jmp .encode
.negative_direction:
    cmp qword [r14 + 8], 0
    jne .increment
    jmp .encode
.nearest:
    mov rdi, rbx
    mov esi, 1
    call __al_big_left
    mov rdi, rbx
    mov rsi, r12
    call __al_big_cmp
    test eax, eax
    js .encode
    jnz .increment
    cmp qword [r14 + 32], 0      ; an omitted nonzero tail breaks a tie upward
    jne .increment
    test r15, 1
    jz .encode
.increment:
    add r15, 1
    jc .normalize
    mov rcx, [rsp + 8]
    cmp rcx, 64
    je .encode
    mov eax, 1
    shl rax, cl
    cmp r15, rax
    jb .encode
.normalize:
    mov rcx, [rsp + 8]
    dec rcx
    mov r15d, 1
    shl r15, cl
    inc qword [rsp + 40]
    mov rax, [rsp + 40]
    cmp rax, [rsp + 24]
    jg .overflow
.encode:
    mov rcx, [rsp + 8]
    dec rcx
    mov eax, 1
    shl rax, cl
    xor edx, edx
    mov rcx, [rsp + 56]
    cmp r15, rax
    jae .normal
    test rcx, rcx
    jz .pack
    or ecx, 16                   ; underflow is tiny and inexact after rounding
    jmp .pack
.normal:
    mov rdx, [rsp + 40]
    add rdx, [rsp + 24]
.pack:
    mov rax, r15
    jmp .done

.tiny:
    xor eax, eax
    xor edx, edx
    mov ecx, 48
    cmp dword [rsp + 32], 1024
    je .tiny_negative
    cmp dword [rsp + 32], 2048
    jne .done
    cmp qword [r14 + 8], 0
    je .least_subnormal
    jmp .done
.tiny_negative:
    cmp qword [r14 + 8], 0
    je .done
.least_subnormal:
    mov eax, 1
    jmp .done

.overflow:
    mov rcx, [rsp + 8]
    dec rcx
    mov eax, 1
    shl rax, cl                  ; explicit leading bit for infinity
    mov rdx, [rsp + 24]
    lea rdx, [rdx + rdx + 1]    ; all exponent bits set
    mov ecx, 40
    cmp dword [rsp + 32], 0
    je .done
    cmp dword [rsp + 32], 1024
    je .overflow_negative
    cmp dword [rsp + 32], 2048
    jne .largest
    cmp qword [r14 + 8], 0
    je .done
    jmp .largest
.overflow_negative:
    cmp qword [r14 + 8], 0
    jne .done
.largest:
    lea rax, [rax + rax - 1]
    dec rdx
.done:
    add rsp, 72
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.__al_float_round alloc noexec nowrite progbits align=4
formats:
    dd 24, -126, 127
    dd 53, -1022, 1023
    dd 64, -16382, 16383

section .note.GNU-stack noalloc noexec nowrite progbits
