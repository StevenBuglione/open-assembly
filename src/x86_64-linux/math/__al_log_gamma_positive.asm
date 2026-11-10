; Return sign in eax and Q256 log-gamma magnitude at rdi for positive Q256 at rsi. rdx holds scratch.
bits 64
default rel

global __al_log_gamma_positive:function
extern __al_big_init128:function
extern __al_big_left:function
extern __al_math_log:function
extern __al_big_add:function
extern __al_big_copy:function
extern __al_big_sub:function
extern __al_big_multiply:function
extern __al_big_right_sticky:function
extern __al_big_cmp:function
extern __al_fixed_big_ratio256:function
extern __al_fixed_mul256:function

section .text.__al_log_gamma_positive alloc exec nowrite progbits
__al_log_gamma_positive:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov qword [r13], 0           ; sum of positive recurrence logarithms
    mov qword [r13 + 10248], 0   ; magnitude of negative recurrence logarithms
    lea rdi, [r13 + 30744]       ; one in Q256
    mov esi, 1
    xor edx, edx
    call __al_big_init128
    lea rdi, [r13 + 30744]
    mov esi, 256
    call __al_big_left

.recurrence:
    cmp qword [r12], 9
    jb .shift_argument
    ja .stirling
    cmp dword [r12 + 40], 64
    jae .stirling
.shift_argument:
    mov rsi, r12
    mov edx, -256
    mov ecx, 5
    lea r8, [r13 + 20496]       ; log(y)
    call __al_math_log
    mov rdi, r13
    test eax, eax
    jz .sum_log
    lea rdi, [r13 + 10248]
.sum_log:
    lea rsi, [r13 + 20496]
    call __al_big_add
    mov rdi, r12
    lea rsi, [r13 + 30744]
    call __al_big_add
    jmp .recurrence

.stirling:
    mov rsi, r12
    mov edx, -256
    mov ecx, 5
    lea r8, [r13 + 20496]
    call __al_math_log

    ; y*(log(y)-1) - (log(y)/2 - log(sqrt(2*pi))).
    lea rdi, [r13 + 40992]
    lea rsi, [r13 + 20496]
    call __al_big_copy
    lea rdi, [r13 + 40992]
    lea rsi, [r13 + 30744]
    call __al_big_sub
    mov rdi, rbx
    mov rsi, r12
    lea rdx, [r13 + 40992]
    call __al_big_multiply
    mov rdi, rbx
    mov esi, 256
    call __al_big_right_sticky
    lea rdi, [r13 + 20496]
    mov esi, 1
    call __al_big_right_sticky
    lea rdi, [r13 + 20496]
    lea rsi, [rel half_log_two_pi]
    call __al_big_sub
    mov rdi, rbx
    lea rsi, [r13 + 20496]
    call __al_big_sub

    ; z=64/y keeps the Stirling correction coefficients small.
    lea rdi, [r13 + 81984]
    lea rsi, [r13 + 30744]
    call __al_big_copy
    lea rdi, [r13 + 81984]
    mov esi, 6
    call __al_big_left
    lea rdi, [r13 + 81984]
    mov rsi, r12
    call __al_big_cmp
    test eax, eax
    jz .unit_ratio
    lea rdi, [r13 + 51240]
    lea rsi, [r13 + 81984]
    mov rdx, r12
    call __al_fixed_big_ratio256
    jmp .square_ratio
.unit_ratio:
    lea rdi, [r13 + 51240]
    lea rsi, [r13 + 30744]
    call __al_big_copy
.square_ratio:
    lea rdi, [r13 + 61488]
    lea rsi, [r13 + 51240]
    mov rdx, rsi
    lea rcx, [r13 + 92232]
    call __al_fixed_mul256
    mov qword [r13 + 71736], 0
    mov r14d, 28
.correction_term:
    lea rdi, [r13 + 40992]
    lea rsi, [r13 + 71736]
    lea rdx, [r13 + 61488]
    lea rcx, [r13 + 92232]
    call __al_fixed_mul256
    dec r14d
    lea rax, [r14 + r14*4]
    lea rsi, [rel coefficients]
    lea rsi, [rsi + rax*8]
    lea rdi, [r13 + 71736]
    call __al_big_copy
    lea rdi, [r13 + 71736]
    lea rsi, [r13 + 40992]
    call __al_big_sub
    test r14d, r14d
    jnz .correction_term

    lea rdi, [r13 + 40992]
    lea rsi, [r13 + 71736]
    lea rdx, [r13 + 51240]
    lea rcx, [r13 + 92232]
    call __al_fixed_mul256
    mov rdi, rbx
    lea rsi, [r13 + 40992]
    call __al_big_add
    mov rdi, rbx
    lea rsi, [r13 + 10248]
    call __al_big_add
    mov rdi, rbx
    mov rsi, r13
    call __al_big_cmp
    test eax, eax
    js .negative
    mov rdi, rbx
    mov rsi, r13
    call __al_big_sub
    xor eax, eax
    jmp .done
.negative:
    lea rdi, [r13 + 40992]
    mov rsi, r13
    call __al_big_copy
    lea rdi, [r13 + 40992]
    mov rsi, rbx
    call __al_big_sub
    mov rdi, rbx
    lea rsi, [r13 + 40992]
    call __al_big_copy
    mov eax, 1
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata.__al_log_gamma_positive alloc noexec nowrite progbits align=8
half_log_two_pi:
    dq 8
    dd 0x3daa155d, 0xdec6a313, 0x13458b4d, 0xcfb08f8d, 0x44192023, 0x94bc9001, 0x25f5a534, 0xeb3f8e43
coefficients:
; Absolute values of B_(2n)/(2n*(2n-1)*64^(2n-1)) in Q256, n=1..28.
    dq 8
    dd 0x55555555, 0x55555555, 0x55555555, 0x55555555, 0x55555555, 0x55555555, 0x55555555, 0x00555555
    dq 8
    dd 0x82d82d82, 0x2d82d82d, 0xd82d82d8, 0x82d82d82, 0x2d82d82d, 0xd82d82d8, 0x82d82d82, 0x0000002d
    dq 7
    dd 0x00d00d00, 0x0d00d00d, 0xd00d00d0, 0x00d00d00, 0x0d00d00d, 0xd00d00d0, 0x00d00d00, 0x00000000
    dq 7
    dd 0xc09c09c0, 0x09c09c09, 0x9c09c09c, 0xc09c09c0, 0x09c09c09, 0x9c09c09c, 0x000009c0, 0x00000000
    dq 6
    dd 0x4e700dca, 0xfe46ae1d, 0x2a3c5631, 0x7539c037, 0xc7f91ab8, 0xdca8f158, 0x00000000, 0x00000000
    dq 6
    dd 0x993c7c81, 0x1f6ab0d9, 0x9993c7c8, 0x81f6ab0d, 0xd9993c7c, 0x001f6ab0, 0x00000000, 0x00000000
    dq 6
    dd 0x06906906, 0x69069069, 0x90690690, 0x06906906, 0x69069069, 0x00000690, 0x00000000, 0x00000000
    dq 6
    dd 0x286cb0f5, 0x175b9fe4, 0x064a8ed3, 0xf5397dc2, 0xe4286cb0, 0x00000001, 0x00000000, 0x00000000
    dq 5
    dd 0xffd0c3b7, 0xb1c0f033, 0xd0c3b7f4, 0xc0f033ff, 0x00b7f4b1, 0x00000000, 0x00000000, 0x00000000
    dq 5
    dd 0x5303a458, 0x3989661f, 0xe7b6f6e7, 0x9c04607c, 0x0000591d, 0x00000000, 0x00000000, 0x00000000
    dq 5
    dd 0x7002d3a7, 0xa7221916, 0xc00b4e9e, 0x9c886459, 0x00000035, 0x00000000, 0x00000000, 0x00000000
    dq 4
    dd 0x781f28e7, 0xcfdc4bae, 0x99983556, 0x27364a4b, 0x00000000, 0x00000000, 0x00000000, 0x00000000
    dq 4
    dd 0x0369d036, 0x69d0369d, 0xd0369d03, 0x00224469, 0x00000000, 0x00000000, 0x00000000, 0x00000000
    dq 4
    dd 0xbb092d23, 0x6fd67fdb, 0x315c3895, 0x00002343, 0x00000000, 0x00000000, 0x00000000, 0x00000000
    dq 4
    dd 0x7b93f711, 0xc2347086, 0x3441134d, 0x0000002a, 0x00000000, 0x00000000, 0x00000000, 0x00000000
    dq 3
    dd 0x0185a6ae, 0x85a6aef1, 0x3a211362, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
    dq 3
    dd 0x62433b79, 0x3d90cede, 0x005b4a68, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
    dq 3
    dd 0x76aea602, 0x8cecf233, 0x0000a228, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
    dq 3
    dd 0x024e6a17, 0x779bc9d4, 0x00000143, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
    dq 3
    dd 0x0f5190a8, 0xd0016f78, 0x00000002, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
    dq 2
    dd 0xe3c7dd57, 0x06f2335b, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
    dq 2
    dd 0xc50eee53, 0x0012efae, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
    dq 2
    dd 0x4cdfd6bc, 0x000038b8, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
    dq 2
    dd 0xe094058a, 0x000000b9, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
    dq 2
    dd 0x97dfbbe7, 0x00000002, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
    dq 1
    dd 0x0a0ef80e, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
    dq 1
    dd 0x002a3aff, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
    dq 1
    dd 0x0000bf58, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000

section .note.GNU-stack noalloc noexec nowrite progbits
