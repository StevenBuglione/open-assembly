; Original self-relocator for the bounded static PIE linker layout.
; rdi = mapped ELF header (load bias), rsi = mapped _DYNAMIC.
bits 64
default rel

global __al_pie_relocate:function
extern __al_runtime_load_bias:data
extern __al_syscall:function

section .text.__al_pie_relocate alloc exec nowrite progbits
__al_pie_relocate:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 104
    ; Stack slots: raw syscall argument, end of headers, first file extent,
    ; dynamic end, RELRO start/end, RELA offset/size/entry size/count,
    ; TLS template start and file-backed end.
    mov r12, rdi
    mov r13, rsi
    sub r13, r12               ; dynamic virtual address
    jc .invalid
    test r12, r12
    jz .invalid
    test r12d, 4095
    jnz .invalid
    cmp dword [r12], 0x464c457f
    jne .invalid
    mov eax, [r12 + 4]
    and eax, 0xffffff
    cmp eax, 0x010102          ; ELF64, little endian, current version
    jne .invalid
    cmp dword [r12 + 16], 0x003e0003 ; ET_DYN, EM_X86_64
    jne .invalid
    cmp dword [r12 + 20], 1
    jne .invalid
    cmp qword [r12 + 32], 64    ; e_phoff
    jne .invalid
    cmp dword [r12 + 52], 0x00380040 ; e_ehsize, e_phentsize
    jne .invalid
    movzx ecx, word [r12 + 56]
    test ecx, ecx
    jz .invalid
    cmp ecx, 64
    ja .invalid
    mov eax, ecx
    imul eax, 56
    add eax, 64
    mov [rsp + 8], rax
    lea rdi, [r12 + 64]
    cmp dword [rdi], 1        ; initial PT_LOAD maps ELF metadata
    jne .invalid
    cmp dword [rdi + 4], 4    ; read-only
    jne .invalid
    cmp qword [rdi + 8], 0
    jne .invalid
    cmp qword [rdi + 16], 0
    jne .invalid
    mov rdx, [rdi + 32]
    cmp rdx, rax
    jb .invalid
    mov [rsp + 16], rdx
    xor ebx, ebx               ; end of all load segments seen
    xor r14d, r14d             ; writable file range start
    xor r15d, r15d             ; writable file range end
    mov qword [rsp + 24], 0
    mov qword [rsp + 32], 0
    mov qword [rsp + 40], 0
    mov qword [rsp + 80], 0

.phdr:
    mov eax, [rdi]
    cmp eax, 1
    je .load
    cmp eax, 2
    je .dynamic
    cmp eax, 3                ; PT_INTERP
    je .invalid
    cmp eax, 7                ; PT_TLS
    je .tls
    cmp eax, 0x6474e552       ; PT_GNU_RELRO
    je .relro
    jmp .next_phdr

.load:
    mov r11d, [rdi + 4]
    cmp r11d, 4
    jb .invalid
    cmp r11d, 6               ; R, RX, or RW
    ja .invalid
    mov rdx, [rdi + 16]
    mov r9, [rdi + 32]
    mov r10, [rdi + 40]
    test r10, r10
    jz .invalid
    cmp r9, r10
    ja .invalid
    mov r8, [rdi + 48]
    cmp r8, 4096
    jb .invalid
    lea rax, [r8 - 1]
    test r8, rax
    jnz .invalid
    mov r8, rdx
    xor r8, [rdi + 8]
    test r8, rax
    jnz .invalid
    mov rax, rdx
    and rax, -4096
    lea r8, [rbx + 4095]
    and r8, -4096
    cmp rax, r8
    jb .invalid
    mov rbx, rdx
    add rbx, r10
    jc .invalid
    cmp rbx, 0x7fffffff
    ja .invalid
    cmp r11d, 6
    jne .next_phdr
    test r15, r15
    jnz .invalid
    mov r14, rdx
    lea r15, [rdx + r9]
    jmp .next_phdr

.dynamic:
    cmp qword [rsp + 24], 0
    jne .invalid
    cmp dword [rdi + 4], 6
    jne .invalid
    cmp r13, [rdi + 16]
    jne .invalid
    mov rdx, [rdi + 32]
    cmp rdx, [rdi + 40]
    jne .invalid
    cmp rdx, 16
    jb .invalid
    cmp rdx, 4096
    ja .invalid
    test dl, 15
    jnz .invalid
    add rdx, r13
    jc .invalid
    mov [rsp + 24], rdx
    jmp .next_phdr

.relro:
    cmp qword [rsp + 32], 0
    jne .invalid
    cmp dword [rdi + 4], 4
    jne .invalid
    mov rdx, [rdi + 16]
    test rdx, rdx
    jz .invalid
    mov r8, [rdi + 40]
    test r8, r8
    jz .invalid
    cmp r8, [rdi + 32]
    jne .invalid
    add r8, rdx
    jc .invalid
    test r8d, 4095
    jnz .invalid
    mov [rsp + 32], rdx
    mov [rsp + 40], r8
    jmp .next_phdr

.tls:
    cmp qword [rsp + 80], 0
    jne .invalid
    cmp dword [rdi + 4], 4
    jne .invalid
    mov rdx, [rdi + 16]
    test rdx, rdx
    jz .invalid
    mov r8, [rdi + 32]
    mov r9, [rdi + 40]
    cmp r8, r9
    ja .invalid
    cmp r9, 0x7fffffff
    ja .invalid
    mov r9, [rdi + 48]
    lea rax, [r9 - 1]
    test r9, rax
    jnz .invalid
    add r8, rdx
    jc .invalid
    mov [rsp + 80], rdx
    mov [rsp + 88], r8

.next_phdr:
    add rdi, 56
    dec ecx
    jnz .phdr
    mov rdi, [rsp + 32]
    cmp rdi, r14
    jb .invalid
    cmp r13, rdi
    jb .invalid
    mov rsi, [rsp + 40]
    cmp rsi, r15
    ja .invalid
    mov rdx, [rsp + 24]
    cmp rdx, r13
    jbe .invalid
    cmp rdx, rsi
    ja .invalid
    mov rax, [rsp + 80]
    test rax, rax
    jz .image_end
    cmp rax, r14
    jb .invalid
    cmp [rsp + 88], r15
    ja .invalid
.image_end:
    ; Validate the absolute end once for all later address additions.
    mov rax, r12
    add rax, rbx
    jc .invalid

    mov qword [rsp + 48], 0
    mov qword [rsp + 56], 0
    mov qword [rsp + 64], 0
    mov qword [rsp + 72], 0
    mov rdi, r13
    mov rsi, [rsp + 24]
    xor ecx, ecx               ; seen NOW and PIE flags
.tag:
    cmp rdi, rsi
    jae .invalid
    mov rax, [r12 + rdi]
    mov rdx, [r12 + rdi + 8]
    add rdi, 16
    test rax, rax
    jz .tag_end
    cmp rax, 7
    je .rela
    cmp rax, 8
    je .relasz
    cmp rax, 9
    je .relaent
    cmp rax, 0x6ffffff9
    je .relacount
    cmp rax, 30
    je .flags
    cmp rax, 0x6ffffffb
    je .flags_1
    ; Pinned linker metadata unused by the self-relocator.
    cmp rax, 4
    je .tag
    cmp rax, 5
    je .tag
    cmp rax, 6
    je .tag
    cmp rax, 10
    je .tag
    cmp rax, 11
    je .tag
    cmp rax, 21
    je .tag
    cmp rax, 0x6ffffef5
    je .tag
    jmp .invalid

.rela:
    cmp qword [rsp + 48], 0
    jne .invalid
    test rdx, rdx
    jz .invalid
    mov [rsp + 48], rdx
    jmp .tag
.relasz:
    cmp qword [rsp + 56], 0
    jne .invalid
    test rdx, rdx
    jz .invalid
    mov [rsp + 56], rdx
    jmp .tag
.relaent:
    cmp qword [rsp + 64], 0
    jne .invalid
    cmp rdx, 24
    jne .invalid
    mov [rsp + 64], rdx
    jmp .tag
.relacount:
    cmp qword [rsp + 72], 0
    jne .invalid
    test rdx, rdx
    jz .invalid
    mov [rsp + 72], rdx
    jmp .tag
.flags:
    test ecx, 1
    jnz .invalid
    cmp rdx, 8                ; DF_BIND_NOW
    jne .invalid
    or ecx, 1
    jmp .tag
.flags_1:
    test ecx, 2
    jnz .invalid
    cmp rdx, 0x08000001       ; DF_1_PIE | DF_1_NOW
    jne .invalid
    or ecx, 2
    jmp .tag

.tag_end:
    test rdx, rdx
    jnz .invalid
    cmp ecx, 3
    jne .invalid
.padding:
    cmp rdi, rsi
    jae .tables
    cmp qword [r12 + rdi], 0
    jne .invalid
    cmp qword [r12 + rdi + 8], 0
    jne .invalid
    add rdi, 16
    jmp .padding

.tables:
    mov r10, [rsp + 48]
    mov rax, [rsp + 56]
    mov r8, r10
    or r8, rax
    or r8, [rsp + 64]
    or r8, [rsp + 72]
    jz .seal
    cmp r10, [rsp + 8]
    jb .invalid
    test r10b, 7
    jnz .invalid
    cmp qword [rsp + 64], 24
    jne .invalid
    cmp rax, 24
    jb .invalid
    cmp rax, 6291456         ; 262144 Elf64_Rela entries
    ja .invalid
    mov r11, r10
    add r11, rax
    jc .invalid
    cmp r11, [rsp + 16]
    ja .invalid
    xor edx, edx
    mov r9d, 24
    div r9
    test rdx, rdx
    jnz .invalid
    mov r8, [rsp + 72]
    test r8, r8
    jz .verify_start
    cmp r8, rax
    jne .invalid

.verify_start:
    mov rdi, r10
    xor esi, esi              ; previous relocation target
.verify:
    cmp qword [r12 + rdi + 8], 8 ; symbol zero, R_X86_64_RELATIVE
    jne .invalid
    mov rax, [r12 + rdi]
    cmp rax, rsi
    jbe .invalid
    cmp rax, r14
    jb .invalid
    cmp rax, r15
    jae .invalid
    test al, 7
    jnz .invalid
    lea rcx, [rax + 8]
    cmp rcx, r15
    ja .invalid
    cmp rcx, r13
    jbe .target_valid
    cmp rax, [rsp + 24]
    jb .invalid
.target_valid:
    mov rdx, [r12 + rdi + 16]
    cmp rdx, rbx
    ja .invalid
    mov rsi, rax
    add rdi, 24
    cmp rdi, r11
    jb .verify

    mov rdi, r10
.relocate:
    mov rax, [r12 + rdi]
    mov rdx, [r12 + rdi + 16]
    add rdx, r12
    mov [r12 + rax], rdx
    add rdi, 24
    cmp rdi, r11
    jb .relocate

.seal:
    mov rsi, [rsp + 32]
    and rsi, -4096
    mov rdx, [rsp + 40]
    sub rdx, rsi
    add rsi, r12
    mov qword [rsp], 0
    mov edi, 10                ; __NR_mprotect
    mov ecx, 1                ; PROT_READ
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    test rax, rax
    jnz .invalid
    mov [rel __al_runtime_load_bias], r12
    xor eax, eax
    jmp .done
.invalid:
    mov eax, 1
.done:
    add rsp, 104
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
