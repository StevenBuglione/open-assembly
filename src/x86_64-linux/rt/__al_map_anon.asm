; Original kernel wrapper. rdi = length; rax = mapping address or NULL.
bits 64
default rel

global __al_map_anon:function
extern __al_syscall:function

section .text.__al_map_anon alloc exec nowrite progbits
__al_map_anon:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov rdx, rdi                  ; length
    mov edi, 9                    ; __NR_mmap
    xor esi, esi                  ; address hint
    mov ecx, 3                    ; PROT_READ | PROT_WRITE
    mov r8d, 34                   ; MAP_PRIVATE | MAP_ANONYMOUS
    mov r9, -1                   ; no file descriptor
    call __al_syscall
    cmp rax, -4095
    jb .done
    xor eax, eax
.done:
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
