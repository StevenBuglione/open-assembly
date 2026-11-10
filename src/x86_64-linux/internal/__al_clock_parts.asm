; Original private clock query. rdi = clock ID. Returns the raw kernel status
; in rax and, on success, seconds in rdx and nanoseconds in rcx.
bits 64
default rel

global __al_clock_parts:function
extern __al_syscall:function

section .text.__al_clock_parts alloc exec nowrite progbits
__al_clock_parts:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    mov qword [rsp], 0
    mov rsi, rdi
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 228                  ; __NR_clock_gettime
    lea rdx, [rsp + 8]            ; Linux time64 result
    call __al_syscall
    cmp rax, -4095
    jae .done
    mov rdx, [rsp + 8]
    mov rcx, [rsp + 16]
.done:
    add rsp, 32
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
