; Test a code unit against a validated wide scanset.
bits 64
default rel

global __al_scan_wmember:function

section .text.__al_scan_wmember alloc exec nowrite progbits
__al_scan_wmember:
    mov eax, 1                  ; result when a member is found
    cmp dword [rdi], 94
    jne .initial_bracket
    xor eax, eax
    add rdi, 4
.initial_bracket:
    cmp dword [rdi], 93
    jne .next
    cmp esi, 93
    je .return
    add rdi, 4
.next:
    mov ecx, [rdi]
    cmp ecx, 93
    je .absent
    cmp dword [rdi + 4], 45
    jne .single
    mov edx, [rdi + 8]
    cmp edx, 93
    je .single
    cmp ecx, edx
    ja .single
    add rdi, 12
    cmp esi, ecx
    jb .next
    cmp esi, edx
    ja .next
    ret
.single:
    add rdi, 4
    cmp esi, ecx
    jne .next
.return:
    ret
.absent:
    xor eax, 1
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
