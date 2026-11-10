; Original locked allocator core. rdi = requested size, rsi = alignment.
; Alignment is a validated power of two >= 16. Returns a pointer or NULL.
bits 64
default rel

global __al_heap_alloc:function
extern __al_map_anon:function
extern __al_heap_tag:function
extern __al_heap_bad:function

section .text.__al_heap_alloc alloc exec nowrite progbits
__al_heap_alloc:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 24
    mov rbx, rdi                  ; requested bytes
    mov r12, rsi                  ; required alignment
    test rbx, rbx
    js .no_memory                 ; size exceeds PTRDIFF_MAX
    cmp r12, 16
    jne .direct
    cmp rbx, 4064
    ja .direct

    lea rax, [rel strides]
    lea r14, [rel available]
.find_class:
    mov r13d, [rax]
    lea rcx, [r13 - 32]          ; slot capacity
    cmp rbx, rcx
    jbe .class_found
    add rax, 4
    add r14, 8
    jmp .find_class
.class_found:
    mov r15, [r14]
    test r15, r15
    jnz .slab_ready

    mov edi, 65536
    call __al_map_anon
    test rax, rax
    jz .no_memory
    mov r15, rax
    mov [r14], r15
    mov [r15 + 8], r14            ; previous link is the head slot
    mov [r15 + 16], r14           ; class head slot
    mov [r15 + 24], r13           ; stride
    lea rax, [r15 + 64]
    mov [r15 + 32], rax           ; next uninitialized slot
    lea rax, [r15 + 65536]
    mov [r15 + 56], rax           ; end of mapping

.slab_ready:
    mov rax, [r15 + 48]           ; recycled slots take priority
    test rax, rax
    jz .bump
    mov [rsp], rax
    lea rcx, [r15 + 64]
    cmp rax, rcx
    jb .damaged
    cmp rax, [r15 + 32]
    jae .damaged
    sub rax, rcx
    xor edx, edx
    div r13
    test rdx, rdx
    jnz .damaged
    mov rdi, [rsp]
    lea rax, [r15 + 2]           ; freed slot of this slab
    cmp [rdi], rax
    jne .damaged
    call __al_heap_tag
    mov rcx, [rsp]
    cmp rax, [rcx + 24]
    jne .damaged
    mov rax, [rcx + 16]
    mov [r15 + 48], rax
    jmp .mark_live

.bump:
    mov rax, [r15 + 32]
    mov [rsp], rax
    add rax, r13
    cmp rax, [r15 + 56]
    ja .damaged
    mov [r15 + 32], rax

.mark_live:
    inc qword [r15 + 40]
    cmp qword [r15 + 48], 0
    jne .publish_small
    mov rax, [r15 + 32]
    add rax, r13
    cmp rax, [r15 + 56]
    jbe .publish_small

    ; A full slab leaves the available list until its next free.
    mov rax, [r15]
    mov [r14], rax
    test rax, rax
    jz .detach
    mov [rax + 8], r14
.detach:
    mov qword [r15], 0
    mov qword [r15 + 8], 0
.publish_small:
    mov rdi, [rsp]
    mov [rdi], r15
    mov [rdi + 8], rbx
    mov qword [rdi + 16], 0
    jmp .sign_header

.direct:
    mov r13, rbx                  ; payload plus header and alignment slack
    test r13, r13
    jnz .direct_size
    inc r13
.direct_size:
    add r13, 32
    jc .no_memory
    lea r14, [r12 - 1]
    add r13, r14
    jc .no_memory
    test r13, r13
    js .no_memory
    mov rdi, r13
    call __al_map_anon
    test rax, rax
    jz .no_memory

    lea rdi, [rax + r14 + 32]
    neg r12
    and rdi, r12                  ; aligned payload address
    sub rdi, 32
    mov [rsp], rdi
    or rax, 1                     ; mark the original mapping as direct
    mov [rdi], rax
    mov [rdi + 8], rbx
    mov [rdi + 16], r13
.sign_header:
    call __al_heap_tag
    mov rcx, [rsp]
    mov [rcx + 24], rax
    lea rax, [rcx + 32]
    jmp .done
.no_memory:
    xor eax, eax
.done:
    add rsp, 24
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.damaged:
    call __al_heap_bad
    ud2

section .rodata.__al_heap_alloc alloc noexec nowrite progbits align=4
strides:
    dd 48, 64, 80, 96, 128, 160, 192, 256
    dd 384, 512, 768, 1024, 1536, 2048, 3072, 4096

section .bss.__al_heap_alloc alloc noexec write nobits align=8
available:
    resq 16

section .note.GNU-stack noalloc noexec nowrite progbits
