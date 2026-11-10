; Original conversion from a bounded POSIX timestamp to TZif UNIX leap time.
; Ignore an expiry record as a correction change. Public time stays leap-free.
bits 64
default rel

global __al_tzif_scale:function

section .text.__al_tzif_scale alloc exec nowrite progbits
__al_tzif_scale:
    mov r8, [rdi + 88]
    mov r9, [rdi + 80]
    mov r10, [rdi + 72]
    xor r11d, r11d               ; preceding correction
.next:
    test r8, r8
    jz .done
    cmp r10, 8
    je .wide
    mov eax, [r9]
    bswap eax
    movsxd rax, eax
    jmp .correction
.wide:
    mov rax, [r9]
    bswap rax
.correction:
    mov edx, [r9 + r10]
    bswap edx
    movsxd rdx, edx
    mov rcx, r11
    cmp rdx, rcx
    jge .threshold
    mov rcx, rdx
.threshold:
    sub rax, rcx                 ; first represented POSIX second after the leap
    jo .done                     ; an overflowing threshold exceeds the input
    cmp rax, rsi
    jg .done
    mov r11, rdx
    lea r9, [r9 + r10 + 4]
    dec r8
    jmp .next
.done:
    lea rax, [rsi + r11]
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
