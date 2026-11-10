; Check and publish the current path. A trailing slash asks the kernel
; to resolve a directory. GLOB_MARK also follows directory symlinks.
bits 64
default rel

global __al_glob_candidate:function
extern lstat:function
extern stat:function
extern __al_glob_path:function
extern __al_glob_add:function

section .text.__al_glob_candidate alloc exec nowrite progbits
__al_glob_candidate:
    push rbx
    mov rbx, rdi
    cmp qword [rbx + 88], 0
    je .skip
    mov rdi, [rbx + 80]
    lea rsi, [rbx + 112]
    call lstat
    test eax, eax
    jnz .skip
    test dword [rbx + 8], 2     ; GLOB_MARK
    jz .publish
    mov rax, [rbx + 80]
    mov rcx, [rbx + 88]
    cmp byte [rax + rcx - 1], 47
    je .publish
    mov eax, [rbx + 136]        ; st_mode
    and eax, 0xf000
    cmp eax, 0x4000             ; S_IFDIR
    je .mark
    cmp eax, 0xa000             ; S_IFLNK
    jne .publish
    mov rdi, [rbx + 80]
    lea rsi, [rbx + 112]
    call stat
    test eax, eax
    jnz .publish
    mov eax, [rbx + 136]
    and eax, 0xf000
    cmp eax, 0x4000
    jne .publish
.mark:
    mov rdi, rbx
    xor esi, esi
    mov edx, 1
    call __al_glob_path
    test eax, eax
    jnz .return
.publish:
    mov rdi, rbx
    mov rsi, [rbx + 80]
    call __al_glob_add
    jmp .return
.skip:
    xor eax, eax
.return:
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
