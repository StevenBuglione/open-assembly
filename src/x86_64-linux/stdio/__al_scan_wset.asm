; Validate a wide scanset and return the cursor after its closing bracket.
bits 64
default rel

global __al_scan_wset:function

section .text.__al_scan_wset alloc exec nowrite progbits
__al_scan_wset:
    cmp dword [rdi], 94
    jne .initial_bracket
    add rdi, 4
.initial_bracket:
    cmp dword [rdi], 93
    jne .next
    add rdi, 4
.next:
    mov eax, [rdi]
    test eax, eax
    jz .failure
    add rdi, 4
    cmp eax, 93
    jne .next
    mov rax, rdi
    ret
.failure:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
