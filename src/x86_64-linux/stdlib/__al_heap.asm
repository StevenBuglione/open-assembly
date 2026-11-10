; Original allocator entry shared by the public wrappers.
; rdi = old pointer, rsi = size, rdx = alignment, rcx = operation.
; Operations: 0 allocate, 1 free, 2 resize, 3 allocate and zero.
; The operation holds the heap lock and leaves errno translation to its caller.
bits 64
default rel

global __al_heap:function
global __al_heap_seed:data
global __al_heap_lock:data
extern __al_auxv:data
extern __al_lock:function
extern __al_unlock:function
extern __al_heap_alloc:function
extern __al_heap_inspect:function
extern __al_heap_remap:function
extern __al_heap_free:function
extern __al_heap_tag:function
extern __al_heap_bad:function
extern memcpy:function
extern memset:function

section .text.__al_heap alloc exec nowrite progbits
__al_heap:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov rbx, rdi                  ; old pointer
    mov r12, rsi                  ; requested bytes
    mov r13, rdx                  ; alignment
    mov r14, rcx                  ; operation
    xor r15d, r15d                ; result
    lea rdi, [rel __al_heap_lock]
    call __al_lock

    cmp qword [rel __al_heap_seed], 0
    jne .dispatch
    ; The immutable startup auxiliary vector supplies a process-wide seed.
    mov rdx, [rel __al_auxv]
.find_random:
    mov rax, [rdx]
    test rax, rax
    jz .no_random
    cmp rax, 25                   ; AT_RANDOM
    je .save_seed
    add rdx, 16
    jmp .find_random
.save_seed:
    mov rax, [rdx + 8]
    mov rax, [rax + 8]
    or rax, 1                     ; zero is reserved for uninitialized state
    mov [rel __al_heap_seed], rax

.dispatch:
    cmp r14, 1
    je .free
    cmp r14, 2
    jne .allocate
    test rbx, rbx
    jz .allocate

    mov rdi, rbx
    call __al_heap_inspect
    cmp r12, rdx
    ja .move
    ; Reuse the capacity and end the old allocation's logical lifetime.
    mov [rbx - 24], r12
    lea rdi, [rbx - 32]
    call __al_heap_tag
    mov [rbx - 8], rax
    mov r15, rbx
    jmp .unlock

.move:
    mov [rsp], rax                ; old requested size
    test rcx, 1                   ; direct allocation, validated by inspect
    jz .copy_grow
    mov rdi, rbx
    mov rsi, r12
    call __al_heap_remap
    test rax, rax
    jz .copy_grow
    mov r15, rax
    jmp .unlock
.copy_grow:
    mov rdi, r12
    mov rsi, r13
    call __al_heap_alloc
    mov r15, rax
    test r15, r15
    jz .unlock                    ; old storage remains live on failure
    mov rdi, r15
    mov rsi, rbx
    mov rdx, [rsp]                ; new size exceeds old capacity
    call memcpy
    mov rdi, rbx
    call __al_heap_free
    jmp .unlock

.allocate:
    mov rdi, r12
    mov rsi, r13
    call __al_heap_alloc
    mov r15, rax
    test r15, r15
    jz .unlock
    cmp r14, 3
    jne .unlock
    mov rdi, r15
    xor esi, esi
    mov rdx, r12
    call memset
    jmp .unlock

.free:
    test rbx, rbx
    jz .unlock
    mov rdi, rbx
    call __al_heap_free
.unlock:
    lea rdi, [rel __al_heap_lock]
    call __al_unlock
    mov rax, r15
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.no_random:
    call __al_heap_bad
    ud2

section .bss.__al_heap alloc noexec write nobits align=8
__al_heap_seed:
    resq 1
__al_heap_lock:
    resd 1

section .note.GNU-stack noalloc noexec nowrite progbits
