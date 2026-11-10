; Original x86-64 clone boundary. Inputs: FS base, child launch record,
; shared parent/clear-TID word. Parent returns raw status. Child cannot return.
bits 64
default rel

global __al_thread_clone:function
extern __al_thread_start:function

section .text.__al_thread_clone alloc exec nowrite progbits
__al_thread_clone:
    mov r8, rdi
    mov r10, rdx
    mov edi, 0x3d0f00
    mov eax, 56                   ; __NR_clone
    syscall
    test rax, rax
    jz .child
    ret
.child:
    xor ebp, ebp
    mov rdi, [rsp]
    mov rsi, [rsp + 8]
    call __al_thread_start
    ud2

section .note.GNU-stack noalloc noexec nowrite progbits
