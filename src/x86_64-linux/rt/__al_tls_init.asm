; Original implementation. rdi is the address of the initial auxiliary vector.
bits 64
default rel

global __al_tls_init:function
extern __al_syscall:function
extern __al_panic:function

section .text.__al_tls_init alloc exec nowrite progbits
__al_tls_init:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    mov qword [rsp], 0             ; arg6 for __al_syscall
    xor r8d, r8d                   ; AT_PHDR
    xor r9d, r9d                   ; AT_PHENT
    xor r10d, r10d                 ; AT_PHNUM
    xor r11d, r11d                 ; AT_RANDOM

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

.auxv_done:
    test r11, r11
    jz .fail
    mov [rsp + 8], r11             ; AT_RANDOM address
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

    mov qword [rsp + 16], 0        ; no TLS source image
    mov qword [rsp + 24], 0        ; no image bytes to copy
    xor ecx, ecx                   ; distance from thread pointer
    mov eax, 16                    ; thread pointer alignment
    jmp .allocate

.have_tls:
    mov rsi, [r8 + 16]             ; p_vaddr (ET_EXEC has zero load bias)
    mov [rsp + 16], rsi
    mov rdx, [r8 + 32]             ; p_filesz
    mov [rsp + 24], rdx
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
    mov [rsp + 32], rcx            ; thread pointer to image distance
    mov [rsp + 40], rax            ; thread pointer alignment
    lea rdx, [rax - 1]
    add rdx, rcx
    jc .fail
    add rdx, 80                    ; TCB storage after the thread pointer
    jc .fail
    mov edi, 9                     ; __NR_mmap
    xor esi, esi                   ; address hint: NULL
    mov ecx, 3                     ; PROT_READ | PROT_WRITE
    mov r8d, 34                    ; MAP_PRIVATE | MAP_ANONYMOUS
    mov r9, -1                     ; anonymous fd
    call __al_syscall
    cmp rax, -4095
    jae .fail

    mov rdx, [rsp + 40]
    lea rcx, [rdx - 1]
    add rax, [rsp + 32]
    add rax, rcx
    neg rdx
    and rax, rdx                   ; thread pointer, aligned up
    mov [rax], rax                 ; FS:0 self pointer
    mov [rax + 0x10], rax
    mov rdi, [rsp + 8]
    mov rdx, [rdi]
    and rdx, -256
    mov [rax + 0x28], rdx          ; stack guard
    mov rdx, [rdi + 8]
    mov [rax + 0x30], rdx          ; pointer guard

    ; The anonymous mapping already zeroed .tbss, padding, and errno.
    mov rdi, rax
    sub rdi, [rsp + 32]            ; image begins below the thread pointer
    mov rsi, [rsp + 16]
    mov rcx, [rsp + 24]
    test rcx, rcx
    jz .install
.copy_image:
    mov dl, [rsi]
    mov [rdi], dl
    inc rsi
    inc rdi
    dec rcx
    jnz .copy_image

.install:
    mov edi, 158                   ; __NR_arch_prctl
    mov esi, 0x1002                ; ARCH_SET_FS
    mov rdx, rax
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    test rax, rax
    jnz .fail
    add rsp, 48
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

section .note.GNU-stack noalloc noexec nowrite progbits
