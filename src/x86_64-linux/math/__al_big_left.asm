; Original checked in-place left shift. rdi = value, rsi = bit count.
bits 64
default rel

global __al_big_left:function
extern __al_big_bad:function

section .text.__al_big_left alloc exec nowrite progbits
__al_big_left:
    mov r11, [rdi]
    test r11, r11
    jz .done
    mov r8, rsi
    shr r8, 5                    ; whole-limb shift
    mov ecx, esi
    and ecx, 31                  ; intra-limb shift
    lea rax, [r11 + r8]
    test ecx, ecx
    jz .bounds
    inc rax
.bounds:
    cmp rax, 2560
    ja .capacity
    test ecx, ecx
    jz .words
    xor r9d, r9d                 ; carry
    xor r10d, r10d
.bits:
    mov eax, [rdi + r10*4 + 8]
    shl rax, cl
    or rax, r9
    mov [rdi + r10*4 + 8], eax
    shr rax, 32
    mov r9, rax
    inc r10
    cmp r10, r11
    jb .bits
    test r9, r9
    jz .words
    mov [rdi + r11*4 + 8], r9d
    inc r11
.words:
    test r8, r8
    jz .save
    mov r10, r11
.move:
    dec r10
    mov eax, [rdi + r10*4 + 8]
    lea rdx, [r10 + r8]
    mov [rdi + rdx*4 + 8], eax
    test r10, r10
    jnz .move
    xor ecx, ecx
.zero:
    mov dword [rdi + rcx*4 + 8], 0
    inc rcx
    cmp rcx, r8
    jb .zero
    add r11, r8
.save:
    mov [rdi], r11
.done:
    ret
.capacity:
    sub rsp, 8
    call __al_big_bad
    ud2

section .note.GNU-stack noalloc noexec nowrite progbits
