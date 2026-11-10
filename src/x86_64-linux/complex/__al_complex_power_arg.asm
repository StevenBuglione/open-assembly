; Argument rdi and its residual r9 at precision r8 from aligned magnitudes rsi/rdx and x sign ecx.
bits 64
default rel

global __al_complex_power_arg:function
extern __al_fork_scratch_locks:data
extern __al_lock:function
extern __al_unlock:function
extern __al_big_copy:function
extern __al_big_cmp:function
extern __al_big_bits:function
extern __al_big_left:function
extern __al_big_sub:function
extern __al_big_add:function
extern __al_big_muladd:function
extern __al_big_right_sticky:function
extern __al_fixed_ratio_precision:function
extern __al_complex_scaled_ratio_precision:function
extern __al_fixed_odd_series:function
extern __al_complex_power_constant:function

section .text.__al_complex_power_arg alloc exec nowrite progbits
__al_complex_power_arg:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 48
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14d, ecx
    mov r15, r8
    mov [rsp + 24], r9
    mov dword [rsp], 0
    mov dword [rsp + 4], 0
    mov dword [rsp + 8], 0
    mov dword [rsp + 12], 0
    mov rax, r15
    neg rax
    mov [rsp + 16], rax
    mov [rsp + 32], rax
    cmp qword [r13], 0
    je .zero_vertical
    cmp qword [r12], 0
    je .vertical_constant
    mov rdi, r13
    mov rsi, r12
    call __al_big_cmp
    test eax, eax
    jz .diagonal_constant
    js .small_first
    mov dword [rsp + 4], 1
    mov rax, r12
    mov r12, r13
    mov r13, rax
.small_first:
    lea rdi, [rel __al_fork_scratch_locks + 92]
    call __al_lock
    lea rdi, [rel smaller]
    mov rsi, r13
    call __al_big_copy
    lea rdi, [rel larger]
    mov rsi, r12
    call __al_big_copy
    lea rdi, [rel auxiliary]
    mov rsi, r13
    call __al_big_copy
    lea rdi, [rel auxiliary]
    mov esi, 1
    call __al_big_left
    lea rdi, [rel auxiliary]
    mov rsi, r12
    call __al_big_cmp
    test eax, eax
    js .untransformed
    mov dword [rsp + 8], 1
    lea rdi, [rel auxiliary]
    mov rsi, r12
    call __al_big_copy
    lea rdi, [rel auxiliary]
    lea rsi, [rel smaller]
    call __al_big_add
    lea rdi, [rel larger]
    lea rsi, [rel smaller]
    call __al_big_sub
    lea rsi, [rel larger]
    lea rdx, [rel auxiliary]
    jmp .fixed_ratio
.untransformed:
    lea rdi, [rel larger]
    call __al_big_bits
    mov r12, rax
    lea rdi, [rel smaller]
    call __al_big_bits
    sub r12, rax
    add r12, r12
    cmp r12, r15
    jbe .ordinary_ratio
    mov rdi, rbx
    lea rsi, [rel smaller]
    lea rdx, [rel larger]
    xor ecx, ecx
    mov r8, r15
    call __al_complex_scaled_ratio_precision
    mov [rsp + 32], rax
    jmp .compose_metadata
.ordinary_ratio:
    lea rsi, [rel smaller]
    lea rdx, [rel larger]
.fixed_ratio:
    lea rdi, [rel ratio]
    mov rcx, r15
    call __al_fixed_ratio_precision
    mov rdi, rbx
    lea rsi, [rel ratio]
    mov rdx, r15
    xor ecx, ecx
    call __al_fixed_odd_series
.compose_metadata:
    mov rdi, [rsp + 24]
    mov rsi, rbx
    call __al_big_copy
    mov r12d, [rsp + 8]         ; coefficient of pi/4
    mov r13d, r12d              ; whether to subtract the series
    cmp dword [rsp + 4], 0
    je .horizontal_complement
    neg r12d
    add r12d, 2
    xor r13d, 1
.horizontal_complement:
    test r14d, r14d
    jz .compose
    neg r12d
    add r12d, 4
    xor r13d, 1
.compose:
    mov [rsp], r12d
    mov [rsp + 12], r13d
    test r12d, r12d
    jz .uncomplemented
    mov rsi, [rsp + 32]
    add rsi, r15
    jz .constant_part
    neg rsi
    mov rdi, rbx
    call __al_big_right_sticky
.constant_part:
    lea rdi, [rel auxiliary]
    mov rsi, r15
    mov edx, 1
    call __al_complex_power_constant
    lea rdi, [rel auxiliary]
    mov esi, r12d
    xor edx, edx
    call __al_big_muladd
    lea rdi, [rel auxiliary]
    mov rsi, rbx
    test r13d, r13d
    jz .add_angle
    call __al_big_sub
    jmp .copy_angle
.add_angle:
    call __al_big_add
.copy_angle:
    mov rdi, rbx
    lea rsi, [rel auxiliary]
    call __al_big_copy
    jmp .unlock
.uncomplemented:
    mov rax, [rsp + 32]
    mov [rsp + 16], rax
.unlock:
    lea rdi, [rel __al_fork_scratch_locks + 92]
    call __al_unlock
    jmp .result

.zero_vertical:
    mov r12d, r14d
    shl r12d, 2
    jmp .constant
.vertical_constant:
    mov r12d, 2
    jmp .constant
.diagonal_constant:
    lea r12d, [r14*2 + 1]
.constant:
    mov rax, [rsp + 24]
    mov qword [rax], 0
    mov qword [rsp + 32], 0
    mov [rsp], r12d
    test r12d, r12d
    jz .zero
    mov rdi, rbx
    mov rsi, r15
    mov edx, 1
    call __al_complex_power_constant
    mov rdi, rbx
    mov esi, r12d
    xor edx, edx
    call __al_big_muladd
    jmp .result
.zero:
    mov qword [rbx], 0
    mov qword [rsp + 16], 0
.result:
    mov rax, [rsp + 16]
    mov edx, [rsp]
    mov rcx, [rsp + 32]
    mov r8d, [rsp + 12]
    add rsp, 48
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .bss alloc noexec write nobits
alignb 16
    resd 1                    ; preserve scratch record offsets
alignb 16
smaller: resb 10248
larger: resb 10248
auxiliary: resb 10248
ratio: resb 2304

section .note.GNU-stack noalloc noexec nowrite progbits
