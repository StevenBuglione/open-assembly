; Replace Q256 magnitude at rdi with edx*pi/4 minus it, using scratch at rsi.
bits 64
default rel

global __al_pi_complement:function
extern __al_pi_q256:function
extern __al_big_sub:function
extern __al_big_copy:function

section .text.__al_pi_complement alloc exec nowrite progbits
__al_pi_complement:
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi
    mov rdi, rsi
    mov esi, edx
    call __al_pi_q256
    mov rdi, r12
    mov rsi, rbx
    call __al_big_sub
    mov rdi, rbx
    mov rsi, r12
    call __al_big_copy
    add rsp, 8
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
