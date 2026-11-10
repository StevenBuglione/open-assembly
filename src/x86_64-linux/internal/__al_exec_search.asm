; Original Linux PATH lookup. Inputs: file, argv, envp, PATH, 4096-byte
; candidate buffer, and an ENOEXEC shell-fallback flag. Returns raw errno.
bits 64
default rel

global __al_exec_search:function
extern __al_execve_raw:function
extern __al_exec_script:function

section .text.__al_exec_search alloc exec nowrite progbits
__al_exec_search:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 24
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov r15, r8
    mov [rsp + 8], r9
    mov qword [rsp + 16], 0       ; seen denial or attempted lookup
    xor ecx, ecx
.name_byte:
    mov al, [rbx + rcx]
    test al, al
    jz .name_ready
    cmp al, 47
    je .direct
    inc rcx
    jmp .name_byte
.name_ready:
    test rcx, rcx
    jz .missing
    cmp rcx, 4096
    jae .too_long
    mov [rsp], rcx
.element:
    mov rsi, r14
.element_byte:
    mov al, [r14]
    test al, al
    jz .element_ready
    cmp al, 58
    je .element_ready
    inc r14
    jmp .element_byte
.element_ready:
    mov rcx, r14
    sub rcx, rsi
    test al, al
    jz .last_element
    inc r14
    jmp .candidate_size
.last_element:
    xor r14d, r14d
.candidate_size:
    mov rdi, r15
    test rcx, rcx
    jz .copy_name
    cmp rcx, 4094
    ja .next
    mov rax, [rsp]
    add rax, rcx
    cmp rax, 4094                 ; directory, slash, basename, and NUL
    ja .next
.copy_directory:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .copy_directory
    mov byte [rdi], 47
    inc rdi
.copy_name:
    xor ecx, ecx
.name_copy_byte:
    mov al, [rbx + rcx]
    mov [rdi + rcx], al
    inc rcx
    test al, al
    jnz .name_copy_byte
    or qword [rsp + 16], 2
    mov rdi, r15
    mov rsi, r12
    mov rdx, r13
    call __al_execve_raw
    cmp rax, -8                   ; ENOEXEC
    je .candidate_script
    cmp rax, -13                  ; EACCES
    je .denied
    cmp rax, -2                   ; ENOENT
    je .next
    cmp rax, -20                  ; ENOTDIR
    je .next
    jmp .done
.denied:
    or qword [rsp + 16], 1
.next:
    test r14, r14
    jnz .element
    test qword [rsp + 16], 1
    jnz .permission
    test qword [rsp + 16], 2
    jnz .missing
.too_long:
    mov rax, -36                  ; ENAMETOOLONG
    jmp .done
.permission:
    mov rax, -13
    jmp .done
.missing:
    mov rax, -2
    jmp .done
.direct:
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    call __al_execve_raw
    cmp rax, -8
    jne .done
    mov r15, rbx
.candidate_script:
    cmp qword [rsp + 8], 0
    je .done
    mov rdi, r15
    mov rsi, r12
    mov rdx, r13
    call __al_exec_script
.done:
    add rsp, 24
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
