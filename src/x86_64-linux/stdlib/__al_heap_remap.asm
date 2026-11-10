; Original locked direct-allocation growth. rdi = validated user pointer,
; rsi = requested bytes exceeding capacity. Returns new pointer or NULL.
bits 64
default rel

global __al_heap_remap:function
extern __al_syscall:function
extern __al_heap_tag:function

section .text.__al_heap_remap alloc exec nowrite progbits
__al_heap_remap:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 8
    mov rbx, rsi                  ; requested bytes
    mov rsi, [rdi - 32]
    and rsi, -2                   ; old mapping base
    mov r12, rdi
    sub r12, rsi                  ; payload offset in the mapping
    mov r13, rbx
    add r13, r12
    jc .failed
    test r13, r13
    js .failed                    ; new mapped extent exceeds PTRDIFF_MAX

    mov rdx, [rdi - 16]           ; old mapped extent
    mov edi, 25                   ; __NR_mremap
    mov rcx, r13                  ; new mapped extent
    mov r8d, 1                    ; MREMAP_MAYMOVE
    xor r9d, r9d
    mov qword [rsp], 0
    call __al_syscall
    cmp rax, -4095
    jae .failed

    lea rdi, [rax + r12 - 32]
    mov r12, rdi                  ; replacement header
    or rax, 1                     ; mark the new mapping as direct
    mov [rdi], rax
    mov [rdi + 8], rbx
    mov [rdi + 16], r13
    call __al_heap_tag
    mov [r12 + 24], rax
    lea rax, [r12 + 32]
    jmp .done
.failed:
    xor eax, eax
.done:
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
