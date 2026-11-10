; Original transition lookup. Inputs: validated TZif zone and signed
; timestamp in its transition time scale. Return the selected type index
; in RAX and whether a trailing rule governs it in RDX.
bits 64
default rel

global __al_tzif_type:function

section .text.__al_tzif_type alloc exec nowrite progbits
__al_tzif_type:
    mov r9, [rdi + 56]           ; timecnt
    test r9, r9
    jz .no_transitions
    xor r8d, r8d                ; lower bound of upper-bound search
    mov r10, [rdi + 16]
    cmp qword [rdi + 72], 8
    je .loop64
.loop32:
    cmp r8, r9
    jae .found
    lea rcx, [r8 + r9]
    shr rcx, 1
    mov eax, [r10 + rcx*4]
    bswap eax
    movsxd rax, eax
    cmp rax, rsi
    jg .above32
    lea r8, [rcx + 1]
    jmp .loop32
.above32:
    mov r9, rcx
    jmp .loop32
.loop64:
    cmp r8, r9
    jae .found
    lea rcx, [r8 + r9]
    shr rcx, 1
    mov rax, [r10 + rcx*8]
    bswap rax
    cmp rax, rsi
    jg .above64
    lea r8, [rcx + 1]
    jmp .loop64
.above64:
    mov r9, rcx
    jmp .loop64
.found:
    xor edx, edx
    test r8, r8
    jz .before
    cmp r8, [rdi + 56]
    jne .type
    cmp qword [rdi + 104], 0
    je .type
    mov edx, 1
.type:
    mov rcx, [rdi + 24]
    movzx eax, byte [rcx + r8 - 1]
    ret
.no_transitions:
    xor edx, edx
    cmp qword [rdi + 104], 0
    je .before
    mov edx, 1
.before:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
