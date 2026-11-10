; Original scanner whitespace skip. rdi = source context.
bits 64
default rel

global __al_scan_space:function
extern __al_scan_peek:function
extern __al_scan_take:function
extern isspace:function
extern iswspace:function

section .text.__al_scan_space alloc exec nowrite progbits
__al_scan_space:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8
    mov rbx, rdi
.next:
    mov rdi, rbx
    call __al_scan_peek
    test rax, rax
    js .done
    mov edi, eax
    cmp qword [rbx + 8], 2
    jae .wide_space
    call isspace
    jmp .class
.wide_space:
    call iswspace
.class:
    test eax, eax
    jz .done
    mov rdi, rbx
    call __al_scan_take
    jmp .next
.done:
    add rsp, 8
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
