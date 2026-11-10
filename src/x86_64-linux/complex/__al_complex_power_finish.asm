; Round exp(U)cis(V+q*pi/2) from a power record at rsi. Return raw components and effects in r9/r10.
bits 64
default rel

global __al_complex_power_finish:function
extern __al_big_bits:function
extern __al_big_copy:function
extern __al_big_left:function
extern __al_big_right_sticky:function
extern __al_big_init128:function
extern __al_big_multiply:function
extern __al_big_muladd:function
extern __al_big_cmp:function
extern __al_big_sub:function
extern __al_complex_align:function
extern __al_complex_power_constant:function
extern __al_fixed_mul256:function
extern __al_math_exp:function
extern __al_math_trig:function
extern __al_round_irrational:function
extern __al_fp_pack_exact:function
extern __al_fp_special:function

section .text.__al_complex_power_finish alloc exec nowrite progbits
__al_complex_power_finish:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 112
    mov ebx, edi
    mov r12, rsi
    mov r13, [r12]
    mov r14, [r12 + 8]
    mov r15d, [r12 + 44]
    mov dword [rsp], 0          ; component index
    mov dword [rsp + 4], 0      ; effects
    mov dword [rsp + 8], 0      ; errno
    mov qword [rsp + 16], -131072
    mov qword [rsp + 24], -131072
    cmp r15d, 3
    jne .phase_order
    mov dword [rsp + 4], 4
    mov dword [rsp + 8], 34
.phase_order:
    cmp qword [r14], 0
    je .amplitude
    mov rdi, r14
    call __al_big_bits
    add rax, [r12 + 24]
    dec rax
    mov [rsp + 16], rax
.amplitude:
    test r15d, r15d
    jnz .component
    cmp qword [r13], 0
    je .one_amplitude
    mov rdi, r13
    call __al_big_bits
    add rax, [r12 + 16]
    dec rax
    mov [rsp + 24], rax
    cmp rax, 16
    jge .extreme_amplitude
    lea rdi, [rel exponential_argument]
    mov rsi, r13
    call __al_big_copy
    mov rsi, [r12 + 16]
    add rsi, 256
    lea rdi, [rel exponential_argument]
    test rsi, rsi
    js .truncate
    call __al_big_left
    jmp .log2_argument
.truncate:
    neg rsi
    call __al_big_right_sticky
.log2_argument:
    cmp qword [rel exponential_argument], 0
    je .one_amplitude
    lea rdi, [rel factor]
    mov esi, 256
    mov edx, 2
    call __al_complex_power_constant
    lea rdi, [rel exponential_argument]
    mov rsi, rdi
    lea rdx, [rel factor]
    lea rcx, [rel words]
    call __al_fixed_mul256
    mov edi, ebx
    lea rsi, [rel exponential_argument]
    mov edx, [r12 + 32]
    mov ecx, 5
    lea r8, [rel exponential]
    call __al_math_exp
    sub rax, 256
    mov [rsp + 32], rax
    jmp .component
.extreme_amplitude:
    mov qword [rsp + 32], 131072
    cmp dword [r12 + 32], 0
    je .init_amplitude
    neg qword [rsp + 32]
    jmp .init_amplitude
.one_amplitude:
    mov qword [rsp + 32], -256
.init_amplitude:
    lea rdi, [rel exponential]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel exponential]
    mov esi, 256
    call __al_big_left
.component:
    ; Rotate the component selector and its sign by the exact quadrant.
    mov eax, [r12 + 40]
    mov ecx, eax
    and ecx, 1
    xor ecx, [rsp]
    mov [rsp + 40], ecx
    mov ecx, [rsp]
    xor ecx, 1
    and ecx, eax
    shr eax, 1
    xor eax, ecx
    and eax, 1
    mov [rsp + 44], eax
    cmp qword [r14], 0
    je .zero_phase
    cmp qword [rsp + 16], -80
    jl .tiny_phase
    mov edi, ebx
    mov rsi, r14
    mov rdx, [r12 + 24]
    mov ecx, 6
    sub ecx, [rsp + 40]
    lea r8, [rel factor]
    mov r9d, [r12 + 36]
    call __al_math_trig
    xor eax, [rsp + 44]
    mov [rsp + 44], eax
    mov [rsp + 80], rdx
    cmp qword [rel factor], 0
    je .signed_zero
.fixed_factor:
    test r15d, r15d
    jnz .limit_factor
    lea rdi, [rel numerator]
    lea rsi, [rel exponential]
    lea rdx, [rel factor]
    call __al_big_multiply
    mov rax, [rsp + 32]
    add rax, [rsp + 80]
    jmp .scale_component
.tiny_phase:
    cmp dword [rsp + 40], 0
    je .cosine_factor
    mov eax, [r12 + 36]
    xor [rsp + 44], eax
    test r15d, r15d
    jnz .limit_factor
    lea rdi, [rel numerator]
    lea rsi, [rel exponential]
    mov rdx, r14
    call __al_big_multiply
    mov rax, [rsp + 32]
    add rax, [r12 + 24]
    jmp .scale_component
.zero_phase:
    cmp dword [rsp + 40], 0
    je .cosine_factor
    mov eax, [r12 + 36]
    xor [rsp + 44], eax
    jmp .signed_zero
.cosine_factor:
    test r15d, r15d
    jnz .limit_factor
    cmp qword [rsp + 24], -80
    jge .amplitude_factor
    cmp qword [r13], 0
    jne .near_unit
    cmp qword [r14], 0
    jne .near_unit
    mov edi, ebx
    mov esi, 1
    xor edx, edx
    mov ecx, [rsp + 44]
    call __al_fp_pack_exact
    jmp .store
.amplitude_factor:
    lea rdi, [rel numerator]
    lea rsi, [rel exponential]
    call __al_big_copy
    mov rax, [rsp + 32]
    jmp .scale_component

.near_unit:
    ; exp(U)cos(V) is near one; compare U against V²/2.
    mov dword [rsp + 48], -1
    cmp dword [r12 + 32], 0
    jne .construct_unit
    cmp qword [r13], 0
    je .construct_unit
    cmp qword [r14], 0
    je .above_unit
    lea rdi, [rel square]
    mov rsi, r14
    mov rdx, r14
    call __al_big_multiply
    lea rdi, [rel square]
    call __al_big_bits
    mov rcx, [r12 + 24]
    lea rcx, [rcx + rcx - 1]
    mov [rsp + 56], rcx
    add rax, rcx
    dec rax
    cmp rax, [rsp + 24]
    jl .above_unit
    jg .construct_unit
    lea rdi, [rel numerator]
    mov rsi, r13
    call __al_big_copy
    lea rdi, [rel numerator]
    lea rsi, [rel square]
    mov rdx, [r12 + 16]
    mov rcx, [rsp + 56]
    call __al_complex_align
    lea rdi, [rel numerator]
    lea rsi, [rel square]
    call __al_big_cmp
    test eax, eax
    jle .construct_unit
.above_unit:
    mov dword [rsp + 48], 1
.construct_unit:
    lea rdi, [rel numerator]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel numerator]
    mov esi, 192
    call __al_big_left
    cmp dword [rsp + 48], 0
    jl .unit_below
    lea rdi, [rel numerator]
    mov esi, 1
    mov edx, 1
    call __al_big_muladd
    jmp .unit_scale
.unit_below:
    lea rdi, [rel square]
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [rel numerator]
    lea rsi, [rel square]
    call __al_big_sub
.unit_scale:
    mov rax, -192
.scale_component:
    mov [rel metadata + 16], rax
    mov eax, [rsp + 44]
    mov [rel metadata + 8], rax
    lea rdi, [rel numerator]
    lea rsi, [rel denominator]
    lea rdx, [rel comparison]
    lea rcx, [rel metadata]
    mov r8d, ebx
    call __al_round_irrational
    or [rsp + 4], ecx
    test ecx, 24
    jz .store
    mov dword [rsp + 8], 34
    jmp .store
.limit_factor:
    cmp r15d, 1
    je .signed_zero
    mov edi, ebx
    xor esi, esi
    mov edx, [rsp + 44]
    call __al_fp_special
    jmp .store
.signed_zero:
    mov edi, ebx
    xor esi, esi
    xor edx, edx
    mov ecx, [rsp + 44]
    call __al_fp_pack_exact
.store:
    cmp dword [rsp], 0
    jne .results
    mov [rsp + 64], rax
    mov [rsp + 72], edx
    mov dword [rsp], 1
    jmp .component
.results:
    mov rcx, rax
    mov r8d, edx
    mov rax, [rsp + 64]
    mov edx, [rsp + 72]
    mov r9d, [rsp + 4]
    mov r10d, [rsp + 8]
    add rsp, 112
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .data alloc noexec write progbits
align 8
metadata:
    dq 0, 0, 0, 2, 0

section .bss alloc noexec write nobits
alignb 16
exponential_argument: resb 10248
exponential: resb 64
factor: resb 128
words: resd 18
numerator: resb 10248
denominator: resb 10248
comparison: resb 10248
square: resb 10248

section .note.GNU-stack noalloc noexec nowrite progbits
