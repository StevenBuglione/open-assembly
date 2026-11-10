; Append a 32-byte AST node. RDI program, ESI opcode, R9D flags,
; and RDX/RCX/R8 operands. Return the node pointer.
bits 64
default rel

global __al_regex_node:function

section .text.__al_regex_node alloc exec nowrite progbits
__al_regex_node:
    mov rax, [rdi + 64]
    shl rax, 5
    add rax, [rdi + 56]
    mov [rax], esi
    mov [rax + 4], r9d
    mov [rax + 8], rdx
    mov [rax + 16], rcx
    mov [rax + 24], r8
    inc qword [rdi + 64]
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
