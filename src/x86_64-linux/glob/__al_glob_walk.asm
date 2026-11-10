; Traverse component frames without recursion. Each frame records the prefix
; length, active directory and literal progress at offsets 24, 32 and 40.
bits 64
default rel

global __al_glob_walk:function
extern opendir:function
extern readdir:function
extern closedir:function
extern fnmatch:function
extern stat:function
extern __al_glob_path:function
extern __al_glob_candidate:function
extern __al_glob_error:function

section .text.__al_glob_walk alloc exec nowrite progbits
__al_glob_walk:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32
    mov rbx, rdi
    mov r13, [rbx + 64]
    mov r12, r13
    mov r14, [rbx + 72]
    test r14, r14
    jz .root_path
    imul r14, 48
    add r14, r13
.enter:
    mov rax, [rbx + 88]
    mov [r12 + 24], rax
    mov qword [r12 + 32], 0
    mov qword [r12 + 40], 0
.next:
    mov rax, [rbx + 80]
    mov rcx, [r12 + 24]
    mov [rbx + 88], rcx
    mov byte [rax + rcx], 0
    cmp qword [r12 + 16], 0
    jne .directory
    cmp qword [r12 + 40], 0
    jne .backtrack
    mov qword [r12 + 40], 1
    mov rsi, [r12]
    jmp .append
.directory:
    cmp qword [r12 + 32], 0
    jne .read
    mov rdi, rax
    test rcx, rcx
    jnz .open
    lea rdi, [rel current]
.open:
    call opendir
    test rax, rax
    jz .open_error
    mov [r12 + 32], rax
.read:
    mov rax, [rbx + 24]
    mov dword [rax], 0
    mov rdi, [r12 + 32]
    call readdir
    test rax, rax
    jz .read_end
    lea rax, [rax + 19]        ; d_name
    mov [rsp], rax
    mov rdi, [r12]
    mov rsi, rax
    mov edx, [rbx + 8]
    and edx, 64                ; GLOB_NOESCAPE
    shr edx, 5
    or edx, 4                  ; FNM_PERIOD
    call fnmatch
    test eax, eax
    jnz .read
    mov rsi, [rsp]
.append:
    mov rdi, rbx
    mov rdx, [r12 + 8]
    call __al_glob_path
    test eax, eax
    jnz .failure
    lea rax, [r12 + 48]
    cmp rax, r14
    je .terminal
    cmp qword [r12 + 16], 0
    je .descend
    mov rdi, [rbx + 80]
    lea rsi, [rbx + 112]
    call stat                  ; skip non-directory wildcard entries
    test eax, eax
    jnz .next
    mov eax, [rbx + 136]
    and eax, 0xf000
    cmp eax, 0x4000
    jne .next
.descend:
    add r12, 48
    jmp .enter
.terminal:
    mov rdi, rbx
    call __al_glob_candidate
    test eax, eax
    jnz .failure
    jmp .next
.open_error:
    mov rax, [rbx + 24]
    mov esi, [rax]
    cmp esi, 20                ; non-directory candidate
    je .backtrack
    cmp esi, 12                ; directory allocation failed
    jne .report
    mov eax, 1                 ; GLOB_NOSPACE
    jmp .failure
.read_end:
    mov rax, [rbx + 24]
    mov esi, [rax]
    test esi, esi
    jz .backtrack
.report:
    mov [rsp + 8], esi
    mov rdi, [rbx + 80]
    cmp qword [rbx + 88], 0
    jne .callback
    lea rdi, [rel current]
.callback:
    mov rdx, [rbx + 16]
    mov ecx, [rbx + 8]
    call __al_glob_error
    test eax, eax
    jz .backtrack
    mov rcx, [rbx + 24]
    mov edx, [rsp + 8]
    mov [rcx], edx
    jmp .failure
.backtrack:
    mov rdi, [r12 + 32]
    test rdi, rdi
    jz .parent
    call closedir
    mov qword [r12 + 32], 0
.parent:
    cmp r12, r13
    je .done
    sub r12, 48
    jmp .next
.done:
    xor eax, eax
    jmp .return
.root_path:
    mov rdi, rbx
    call __al_glob_candidate
    jmp .return
.failure:
    mov r15d, eax
    mov rax, [rbx + 24]
    mov eax, [rax]
    mov [rsp + 8], eax
.close_active:
    mov rdi, [r12 + 32]
    test rdi, rdi
    jz .unwind
    call closedir
.unwind:
    cmp r12, r13
    je .restore_error
    sub r12, 48
    jmp .close_active
.restore_error:
    mov rax, [rbx + 24]
    mov edx, [rsp + 8]
    mov [rax], edx
    mov eax, r15d
.return:
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

section .rodata.__al_glob_walk alloc noexec nowrite progbits
current: db ".", 0

section .note.GNU-stack noalloc noexec nowrite progbits
