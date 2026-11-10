; Repair Linux and runtime bookkeeping for the single surviving thread.
; The caller already holds the persistent fork guards and blocks signals.
bits 64
default rel

global __al_fork_child:function
extern __al_thread_count:data
extern __al_panic:function
extern __al_syscall:function
extern pthread_self:function

section .text.__al_fork_child alloc exec nowrite progbits
__al_fork_child:
    push rbx
    sub rsp, 16
    call pthread_self
    mov rbx, rax
    mov qword [rsp], 0
    mov edi, 218               ; __NR_set_tid_address
    lea rsi, [rbx + 0x70]
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    test rax, rax
    jle .failure
    mov [rbx + 0x70], eax
    mov dword [rbx + 0x74], 0  ; the survivor owns the root lifecycle
    mov qword [rbx + 0x78], 0
    mov qword [rbx + 0x100], 0
    mov qword [rbx + 0x108], 0
    mov dword [rel __al_thread_count], 1
    add rsp, 16
    pop rbx
    ret
.failure:
    lea rdi, [rel child_error]
    mov esi, 44
    call __al_panic
    ud2

section .rodata.__al_fork_child alloc noexec nowrite progbits
child_error: db "open-assembly: cannot repair fork child TID", 10

section .note.GNU-stack noalloc noexec nowrite progbits
