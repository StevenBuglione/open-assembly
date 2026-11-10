; Original locked deallocation core. rdi is a nonnull live pointer.
bits 64
default rel

global __al_heap_free:function
extern __al_heap_inspect:function
extern __al_heap_tag:function
extern __al_unmap_anon:function

section .text.__al_heap_free alloc exec nowrite progbits
__al_heap_free:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov rbx, rdi
    call __al_heap_inspect
    test rcx, 1
    jz .small
    mov rdi, rcx
    and rdi, -2
    mov rsi, [rbx - 16]           ; direct mapping length
    call __al_unmap_anon
    jmp .done

.small:
    mov r12, rcx                  ; slab address
    cmp qword [r12 + 8], 0
    jne .decrement
    ; A previously full slab regains space and joins the head of its class.
    mov rdi, [r12 + 16]
    mov rax, [rdi]
    mov [r12], rax
    mov [r12 + 8], rdi
    mov [rdi], r12
    test rax, rax
    jz .decrement
    mov [rax + 8], r12
.decrement:
    dec qword [r12 + 40]
    jnz .recycle

    ; Keep an empty slab only when it is the entire available list.
    mov rdi, [r12 + 8]
    mov rax, [r12]
    cmp rdi, [r12 + 16]
    jne .remove
    test rax, rax
    jz .recycle
.remove:
    mov [rdi], rax
    test rax, rax
    jz .unmap_slab
    mov [rax + 8], rdi
.unmap_slab:
    mov rdi, r12
    mov esi, 65536
    call __al_unmap_anon
    jmp .done

.recycle:
    lea rdi, [rbx - 32]
    lea rax, [r12 + 2]            ; slab owner with free marker
    mov [rdi], rax
    mov qword [rdi + 8], 0
    mov rax, [r12 + 48]
    mov [rdi + 16], rax
    call __al_heap_tag
    lea rdi, [rbx - 32]
    mov [rdi + 24], rax
    mov [r12 + 48], rdi
.done:
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
