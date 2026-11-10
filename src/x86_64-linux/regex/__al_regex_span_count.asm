; Count UTF-8 units in a captured span. Its endpoints are unit boundaries.
bits 64
default rel

global __al_regex_span_count:function
extern __al_fnmatch_unit:function

section .text.__al_regex_span_count alloc exec nowrite progbits
__al_regex_span_count:
    push rbx
    push r12
    push r13
    mov rbx, rdi
    mov r12, rsi
    xor r13d, r13d
.next:
    cmp rbx, r12
    jae .done
    mov rdi, rbx
    mov esi, 1
    call __al_fnmatch_unit
    add rbx, rdx
    inc r13
    jmp .next
.done:
    mov rax, r13
    pop r13
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
