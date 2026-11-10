; Store esi times the Q256 lower enclosure of pi/4 at rdi.
bits 64
default rel

global __al_pi_q256:function
extern __al_big_copy:function
extern __al_big_muladd:function

section .text.__al_pi_q256 alloc exec nowrite progbits
__al_pi_q256:
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rdi
    mov r12d, esi
    lea rsi, [rel quarter_pi]
    call __al_big_copy
    mov rdi, rbx
    mov esi, r12d
    xor edx, edx
    call __al_big_muladd
    add rsp, 8
    pop r12
    pop rbx
    ret

section .rodata.__al_pi_q256 alloc noexec nowrite progbits align=8
quarter_pi:
    dq 8
    dd 0x3b139b22, 0x020bbea6, 0x8a67cc74, 0x29024e08
    dd 0x80dc1cd1, 0xc4c6628b, 0x2168c234, 0xc90fdaa2

section .note.GNU-stack noalloc noexec nowrite progbits
