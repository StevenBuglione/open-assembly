; Match a bounded ASCII class name against the selected wide character class.
; ECX carries the captured character mode. Return minus one for an unknown
; name, otherwise zero or one.
bits 64
default rel

global __al_fnmatch_class:function
extern wctype:function
extern __al_unicode_mask:function

section .text.__al_fnmatch_class alloc exec nowrite progbits
__al_fnmatch_class:
    push rbx
    push r12
    push r13
    mov ebx, edx
    mov r12d, ecx
    and r12d, 1
    inc r12d
    test rsi, rsi
    jz .unknown
    cmp rsi, 6
    ja .unknown
    lea r8, [rel classes]
    lea r9, [rel classes_end]
.next:
    cmp byte [r8 + rsi], 0
    jne .advance
    xor ecx, ecx
.compare:
    mov al, [rdi + rcx]
    cmp al, [r8 + rcx]
    jne .advance
    inc rcx
    cmp rcx, rsi
    jb .compare
    mov rdi, r8
    call wctype
    mov r13d, eax
    mov edi, ebx
    mov esi, r12d
    call __al_unicode_mask
    and eax, r13d
    jz .return
    mov eax, 1
    jmp .return
.advance:
    add r8, 8
    cmp r8, r9
    jb .next
.unknown:
    mov eax, -1
.return:
    pop r13
    pop r12
    pop rbx
    ret

section .rodata.__al_fnmatch_class alloc noexec nowrite progbits
classes:
    db "alnum", 0, 0, 0
    db "alpha", 0, 0, 0
    db "blank", 0, 0, 0
    db "cntrl", 0, 0, 0
    db "digit", 0, 0, 0
    db "graph", 0, 0, 0
    db "lower", 0, 0, 0
    db "print", 0, 0, 0
    db "punct", 0, 0, 0
    db "space", 0, 0, 0
    db "upper", 0, 0, 0
    db "xdigit", 0, 0
classes_end:

section .note.GNU-stack noalloc noexec nowrite progbits
