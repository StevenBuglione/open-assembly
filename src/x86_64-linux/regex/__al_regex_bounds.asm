; Parse an interval after an opening brace. RDI cursor and ESI compile flags.
; Return RAX next cursor, EDX minimum and RCX maximum (-1 is unbounded).
; Zero RAX returns a REG diagnostic in EDX.
bits 64
default rel

global __al_regex_bounds:function

section .text.__al_regex_bounds alloc exec nowrite progbits
__al_regex_bounds:
    xor r8d, r8d                ; parsed minimum
    xor r9d, r9d                ; current bound
    xor r10d, r10d              ; current bound has digits
    xor r11d, r11d              ; one comma already present
.digit:
    movzx eax, byte [rdi]
    lea ecx, [rax - 48]
    cmp ecx, 9
    ja .delimiter
    imul r9d, 10
    add r9d, ecx
    cmp r9d, 255                ; supported POSIX RE_DUP_MAX
    ja .bad_bounds
    inc rdi
    mov r10d, 1
    jmp .digit
.delimiter:
    test eax, eax
    jz .unclosed
    cmp eax, 44
    jne .closing
    test r11d, r11d
    jnz .bad_bounds
    test r10d, r10d
    jz .bad_bounds
    mov r11d, 1
    mov r8d, r9d
    xor r9d, r9d
    xor r10d, r10d
    inc rdi
    jmp .digit
.closing:
    test esi, 1                 ; REG_EXTENDED
    jnz .brace
    cmp eax, 92
    jne .bad_bounds
    inc rdi
    movzx eax, byte [rdi]
    test eax, eax
    jz .unclosed
.brace:
    cmp eax, 125
    jne .bad_bounds
    lea rax, [rdi + 1]
    test r11d, r11d
    jnz .range
    test r10d, r10d
    jz .bad_bounds
    mov edx, r9d
    mov ecx, r9d
    ret
.range:
    mov edx, r8d
    mov rcx, -1
    test r10d, r10d
    jz .done
    cmp r9d, r8d
    jb .bad_bounds
    mov ecx, r9d
.done:
    ret
.unclosed:
    mov edx, 9                 ; REG_EBRACE
    jmp .error
.bad_bounds:
    mov edx, 10                ; REG_BADBR
.error:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
