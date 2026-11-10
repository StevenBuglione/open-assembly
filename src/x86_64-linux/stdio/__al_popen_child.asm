; Original popen child setup. rdi = command, rsi = parent end, rdx = child
; end, rcx = standard descriptor to replace.
bits 64
default rel

global __al_popen_child:function
extern __al_streams:data
extern __al_fcntl:function
extern __al_shell_exec:function
extern close:function
extern dup2:function
extern _exit:function

section .text.__al_popen_child alloc exec nowrite progbits
__al_popen_child:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12, rdx
    mov r13, rcx
    mov rdi, rsi
    call close
    mov r14, [rel __al_streams]
.previous:
    test r14, r14
    jz .redirect
    cmp qword [r14 + 88], 0      ; previous popen child association
    jle .advance
    mov rdi, [r14]
    call close
.advance:
    mov r14, [r14 + 16]
    jmp .previous
.redirect:
    cmp r12, r13
    je .same_fd
    mov rdi, r12
    mov rsi, r13
    call dup2
    test eax, eax
    js .failed
    mov rdi, r12
    call close
    jmp .exec
.same_fd:
    mov rdi, r12
    mov esi, 2                    ; F_SETFD clears close-on-exec
    xor edx, edx
    call __al_fcntl
    cmp rax, -4095
    jae .failed
.exec:
    mov rdi, rbx
    call __al_shell_exec
    ud2
.failed:
    mov edi, 127
    call _exit
    ud2

section .note.GNU-stack noalloc noexec nowrite progbits
