; Original environment ownership collection. Caller holds the environment lock.
; Every owned node starts with its next link and byte length, then the string.
bits 64
default rel

global __al_env_collect:function
extern __al_env_owned:data
extern environ:data
extern free:function

section .text.__al_env_collect alloc exec nowrite progbits
__al_env_collect:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    lea rbx, [rel __al_env_owned]  ; link to the current owned node
.next_node:
    mov r12, [rbx]
    test r12, r12
    jz .done
    lea rdx, [r12 + 16]           ; beginning of this node's installed string
    mov rsi, [r12 + 8]
    add rsi, rdx                  ; end of the owned string storage
    mov rcx, [rel environ]
    test rcx, rcx
    jz .release
.next_entry:
    mov rax, [rcx]
    test rax, rax
    jz .release
    cmp rax, rdx
    jb .advance
    cmp rax, rsi
    jb .keep                      ; a replacement vector may reference a suffix
.advance:
    add rcx, 8
    jmp .next_entry
.release:
    mov rax, [r12]
    mov [rbx], rax
    mov rdi, r12
    call free
    jmp .next_node
.keep:
    mov rbx, r12
    jmp .next_node
.done:
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
