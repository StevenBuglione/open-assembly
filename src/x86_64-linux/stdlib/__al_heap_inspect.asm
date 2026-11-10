; Original locked allocation validator. rdi = live user pointer.
; Returns requested size in rax, capacity in rdx, tagged owner in rcx.
bits 64
default rel

global __al_heap_inspect:function
extern __al_heap_tag:function
extern __al_heap_bad:function

section .text.__al_heap_inspect alloc exec nowrite progbits
__al_heap_inspect:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8
    mov rbx, rdi
    cmp rdi, 32
    jb .damaged
    test rdi, 15
    jnz .damaged
    sub rdi, 32
    call __al_heap_tag
    lea rdi, [rbx - 32]
    cmp rax, [rdi + 24]
    jne .damaged
    mov rcx, [rdi]
    test rcx, rcx
    jz .damaged
    test rcx, 2                  ; freed slab slot
    jnz .damaged
    test rcx, 1
    jnz .direct

    test rcx, 4095               ; mapped slab begins at a page boundary
    jnz .damaged
    lea r8, [rcx + 64]
    cmp rdi, r8
    jb .damaged
    cmp rdi, [rcx + 32]
    jae .damaged
    cmp qword [rcx + 40], 0
    je .damaged
    mov rsi, [rcx + 24]           ; slot stride
    cmp rsi, 48
    jb .damaged
    cmp rsi, 4096
    ja .damaged
    test rsi, 15
    jnz .damaged
    mov rax, rdi
    sub rax, r8
    xor edx, edx
    div rsi
    test rdx, rdx
    jnz .damaged
    lea rdx, [rsi - 32]
    jmp .verify_size

.direct:
    mov r8, rcx
    and r8, -2
    test r8, 4095
    jnz .damaged
    cmp rdi, r8
    jb .damaged
    mov r9, rbx
    sub r9, r8                   ; payload offset from the mapping address
    mov rdx, [rdi + 16]
    cmp rdx, r9
    jb .damaged
    sub rdx, r9
.verify_size:
    mov rax, [rdi + 8]
    cmp rax, rdx
    ja .damaged
    add rsp, 8
    pop rbx
    pop rbp
    ret
.damaged:
    call __al_heap_bad
    ud2

section .note.GNU-stack noalloc noexec nowrite progbits
