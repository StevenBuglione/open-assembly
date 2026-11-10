; Original implementation. rdi is the address of the initial auxiliary vector.
bits 64
default rel

global __al_tls_init:function
global __al_tls_template:data
global __al_runtime_load_bias:data
extern __al_syscall:function
extern __al_tls_new:function
extern __al_panic:function

section .text.__al_tls_init alloc exec nowrite progbits
__al_tls_init:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 24
    mov qword [rsp], 0             ; arg6 for __al_syscall
    xor r8d, r8d                   ; AT_PHDR
    xor r9d, r9d                   ; AT_PHENT
    xor r10d, r10d                 ; AT_PHNUM
    xor r11d, r11d                 ; AT_RANDOM
    xor ebx, ebx                   ; AT_PAGESZ

.scan_auxv:
    mov rax, [rdi]
    test rax, rax
    jz .auxv_done
    mov rdx, [rdi + 8]
    add rdi, 16
    cmp rax, 3                     ; AT_PHDR
    je .save_phdr
    cmp rax, 4                     ; AT_PHENT
    je .save_phent
    cmp rax, 5                     ; AT_PHNUM
    je .save_phnum
    cmp rax, 6                     ; AT_PAGESZ
    je .save_pagesz
    cmp rax, 25                    ; AT_RANDOM
    jne .scan_auxv
    mov r11, rdx
    jmp .scan_auxv
.save_phdr:
    mov r8, rdx
    jmp .scan_auxv
.save_phent:
    mov r9, rdx
    jmp .scan_auxv
.save_phnum:
    mov r10, rdx
    jmp .scan_auxv

.save_pagesz:
    mov rbx, rdx
    jmp .scan_auxv

.auxv_done:
    test r11, r11
    jz .fail
    cmp rbx, 4096
    jb .fail
    cmp rbx, 1048576
    ja .fail
    lea rax, [rbx - 1]
    test rbx, rax
    jnz .fail
    mov [rel __al_tls_template + 48], rbx
    mov rax, [r11]
    and rax, -256
    mov [rel __al_tls_template + 32], rax
    mov rax, [r11 + 8]
    mov [rel __al_tls_template + 40], rax
    test r8, r8
    jz .fail
    cmp r9, 56                     ; sizeof(Elf64_Phdr)
    jne .fail
    test r10, r10
    jz .fail
    cmp r10, 65535
    ja .fail

.scan_phdr:
    cmp dword [r8], 7              ; PT_TLS
    je .have_tls
    add r8, 56
    dec r10
    jnz .scan_phdr

    xor ecx, ecx                   ; distance from thread pointer
    mov eax, 16                    ; thread pointer alignment
    jmp .allocate

.have_tls:
    mov rsi, [r8 + 16]             ; p_vaddr
    add rsi, [rel __al_runtime_load_bias]
    jc .fail
    mov [rel __al_tls_template], rsi
    mov rdx, [r8 + 32]             ; p_filesz
    mov [rel __al_tls_template + 8], rdx
    mov rcx, [r8 + 40]             ; p_memsz
    cmp rdx, rcx
    ja .fail

    mov rax, [r8 + 48]             ; p_align
    test rax, rax
    jnz .nonzero_align
    mov eax, 1
.nonzero_align:
    lea rdx, [rax - 1]
    test rax, rdx                  ; alignment must be a power of two
    jnz .fail
    and rsi, rdx                   ; residue = p_vaddr & (p_align - 1)
    add rcx, rsi
    jc .fail
    add rcx, rdx
    jc .fail
    mov rdx, rax
    neg rdx
    and rcx, rdx                   ; align_up(p_memsz + residue, p_align)
    sub rcx, rsi                   ; subtract the template residue
    cmp rax, 16
    jae .allocate
    mov eax, 16

.allocate:
    mov [rel __al_tls_template + 16], rcx
    mov [rel __al_tls_template + 24], rax
    call __al_tls_new
    test rax, rax
    jz .fail
    mov rbx, rax
    mov edi, 158                   ; __NR_arch_prctl
    mov esi, 0x1002                ; ARCH_SET_FS
    mov rdx, rax
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    test rax, rax
    jnz .fail
    mov edi, 218                   ; __NR_set_tid_address
    lea rsi, [rbx + 0x70]
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    test rax, rax
    jle .fail
    mov [rbx + 0x70], eax
    add rsp, 24
    pop rbx
    pop rbp
    ret

.fail:
    lea rdi, [rel tls_error]
    mov esi, 37
    call __al_panic
    ud2

section .rodata.__al_tls_init alloc noexec nowrite progbits
tls_error:
    db "open-assembly: cannot initialize TLS", 10

section .bss.__al_tls_init alloc noexec write nobits align=8
__al_tls_template:
    resq 7                         ; image, size, displacement, alignment, guards, page

__al_runtime_load_bias: resq 1

section .note.GNU-stack noalloc noexec nowrite progbits
