; Round rdi divided by 2^esi with sign edx and mode ecx. Return magnitude and inexact indicator.
bits 64
default rel

global __al_fp_round_shift:function

section .text.__al_fp_round_shift alloc exec nowrite progbits
__al_fp_round_shift:
    mov r8d, ecx
    mov ecx, esi
    mov rax, rdi
    xor r9d, r9d
    test esi, esi
    jle .done
    test rdi, rdi
    jz .done
    cmp esi, 64
    jae .all_fraction
    shr rax, cl
    mov r9, rax
    shl r9, cl
    xor r9, rdi
    jz .done
    jmp .fraction
.all_fraction:
    xor eax, eax
    mov r9, rdi
.fraction:
    test r8d, r8d
    jz .nearest
    cmp r8d, 4096
    je .nearest
    cmp r8d, 1024
    je .down
    cmp r8d, 2048
    jne .done
    test edx, edx
    jz .increment
    jmp .done
.down:
    test edx, edx
    jnz .increment
    jmp .done
.nearest:
    cmp esi, 64
    ja .done
    dec ecx
    mov r10d, 1
    shl r10, cl
    cmp r9, r10
    ja .increment
    jb .done
    test r8d, r8d
    jnz .increment
    test al, 1
    jz .done
.increment:
    inc rax
.done:
    xor edx, edx
    test r9, r9
    jz .return
    mov edx, 1
.return:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
