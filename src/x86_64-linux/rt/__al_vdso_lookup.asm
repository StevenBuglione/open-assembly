; Original bounded ELF64 lookup. Input is a readable image copy and its
; length. Return the offset of __vdso_clock_gettime@LINUX_2.6, or zero.
bits 64
default rel

global __al_vdso_lookup:function
extern __al_vdso_dynamic:function

section .text.__al_vdso_lookup alloc exec nowrite progbits
__al_vdso_lookup:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 56
    ; Slots: strtab, strsz, symtab, symbol count, versym, verdef.
    mov r12, rdi
    test r12, r12
    jz .invalid
    cmp rsi, 64
    jb .invalid
    cmp rsi, 16384
    ja .invalid
    mov rax, r12
    add rax, rsi
    jc .invalid

    cmp dword [r12], 0x464c457f
    jne .invalid
    mov eax, [r12 + 4]
    and eax, 0xffffff
    cmp eax, 0x010102            ; ELFCLASS64, ELFDATA2LSB, EV_CURRENT
    jne .invalid
    cmp dword [r12 + 16], 0x003e0003 ; ET_DYN, EM_X86_64
    jne .invalid
    cmp dword [r12 + 20], 1
    jne .invalid
    cmp dword [r12 + 52], 0x00380040 ; e_ehsize = 64, e_phentsize = 56
    jne .invalid
    movzx ecx, word [r12 + 56]
    test ecx, ecx
    jz .invalid
    cmp ecx, 32
    ja .invalid
    mov rax, [r12 + 32]          ; e_phoff
    cmp rax, 64
    jb .invalid
    mov ebx, ecx
    imul rbx, 56
    add rbx, rax                 ; end of program headers
    jc .invalid
    cmp rbx, rsi
    ja .invalid
    xor r13d, r13d              ; PT_LOAD file extent
    xor r14d, r14d              ; PT_DYNAMIC file offset
    xor r15d, r15d              ; PT_DYNAMIC byte count
.phdr:
    lea rdx, [r12 + rax]
    cmp dword [rdx], 1
    je .load
    cmp dword [rdx], 2
    jne .phdr_next
    test r14, r14
    jnz .invalid
    mov r14, [rdx + 8]          ; p_offset
    cmp r14, 64
    jb .invalid
    cmp r14, [rdx + 16]         ; p_vaddr
    jne .invalid
    mov r15, [rdx + 32]         ; p_filesz
    cmp r15, [rdx + 40]         ; p_memsz
    jne .invalid
    cmp r15, 16
    jb .invalid
    cmp r15, 4096
    ja .invalid
    test r15b, 15
    jnz .invalid
    jmp .phdr_next
.load:
    test r13, r13
    jnz .invalid
    cmp dword [rdx + 4], 5       ; PF_R | PF_X
    jne .invalid
    cmp qword [rdx + 8], 0
    jne .invalid
    cmp qword [rdx + 16], 0
    jne .invalid
    mov r13, [rdx + 32]
    cmp r13, [rdx + 40]
    jne .invalid
    cmp r13, rbx
    jb .invalid
    cmp r13, rsi
    ja .invalid
.phdr_next:
    add rax, 56
    dec ecx
    jnz .phdr
    test r14, r14
    jz .invalid
    mov rax, r14
    add rax, r15
    jc .invalid
    cmp rax, r13
    ja .invalid
    add r14, r12
    shr r15, 4                  ; count of Elf64_Dyn records

    mov rdi, r14
    mov rsi, r15
    mov edx, 4                  ; DT_HASH
    call __al_vdso_dynamic
    cmp rax, 64
    jb .invalid
    mov rcx, r13
    sub rcx, 8
    cmp rax, rcx
    ja .invalid
    mov ecx, [r12 + rax]        ; nbucket
    test ecx, ecx
    jz .invalid
    cmp ecx, 512
    ja .invalid
    mov edx, [r12 + rax + 4]    ; nchain is the dynamic symbol count
    test edx, edx
    jz .invalid
    cmp edx, 512
    ja .invalid
    add ecx, edx
    lea rax, [rax + rcx * 4 + 8]
    cmp rax, r13
    ja .invalid
    mov [rsp + 24], rdx

    mov rdi, r14
    mov rsi, r15
    mov edx, 5                  ; DT_STRTAB
    call __al_vdso_dynamic
    cmp rax, 64
    jb .invalid
    cmp rax, r13
    jae .invalid
    mov [rsp], rax
    mov rdi, r14
    mov rsi, r15
    mov edx, 10                 ; DT_STRSZ
    call __al_vdso_dynamic
    cmp rax, 21
    jb .invalid
    mov rcx, r13
    sub rcx, [rsp]
    cmp rax, rcx
    ja .invalid
    mov [rsp + 8], rax

    mov rdi, r14
    mov rsi, r15
    mov edx, 11                 ; DT_SYMENT
    call __al_vdso_dynamic
    cmp rax, 24
    jne .invalid
    mov rdi, r14
    mov rsi, r15
    mov edx, 6                  ; DT_SYMTAB
    call __al_vdso_dynamic
    cmp rax, 64
    jb .invalid
    mov rcx, [rsp + 24]
    imul rcx, 24
    add rcx, rax
    jc .invalid
    cmp rcx, r13
    ja .invalid
    mov [rsp + 16], rax

    mov rdi, r14
    mov rsi, r15
    mov edx, 0x6ffffff0         ; DT_VERSYM
    call __al_vdso_dynamic
    cmp rax, 64
    jb .invalid
    mov rcx, [rsp + 24]
    shl rcx, 1
    add rcx, rax
    jc .invalid
    cmp rcx, r13
    ja .invalid
    mov [rsp + 32], rax
    mov rdi, r14
    mov rsi, r15
    mov edx, 0x6ffffffc         ; DT_VERDEF
    call __al_vdso_dynamic
    cmp rax, 64
    jb .invalid
    mov rcx, r13
    sub rcx, 20
    cmp rax, rcx
    ja .invalid
    mov [rsp + 40], rax
    mov rdi, r14
    mov rsi, r15
    mov edx, 0x6ffffffd         ; DT_VERDEFNUM
    call __al_vdso_dynamic
    test rax, rax
    jz .invalid
    cmp rax, 32
    ja .invalid

    mov r15, rax
    mov r14, [rsp + 40]
    mov rbx, [rsp]
    add rbx, r12                ; dynamic strings
    lea rdi, [r13 - 20]         ; maximum Elf64_Verdef offset
    xor r8d, r8d               ; index of the desired version
.version:
    cmp r14, rdi
    ja .invalid
    lea rdx, [r12 + r14]
    cmp word [rdx], 1           ; VER_DEF_CURRENT
    jne .invalid
    cmp word [rdx + 6], 1       ; one auxiliary name in this layout
    jne .invalid
    mov esi, [rdx + 12]         ; vd_aux
    cmp esi, 20
    jb .invalid
    add rsi, r14               ; version offset is at most 16 KiB
    lea rcx, [r13 - 8]
    cmp rsi, rcx
    ja .invalid
    cmp dword [r12 + rsi + 4], 0 ; final vda_next
    jne .invalid
    mov eax, [r12 + rsi]       ; vda_name
    mov rcx, [rsp + 8]
    cmp rax, rcx
    jae .invalid
    sub rcx, 10
    cmp rax, rcx
    ja .version_next
    lea r9, [rbx + rax]
    mov rcx, 0x2e325f58554e494c ; LINUX_2.
    cmp [r9], rcx
    jne .version_next
    cmp word [r9 + 8], 0x0036   ; 6 and NUL
    jne .version_next
    test r8d, r8d
    jnz .invalid
    cmp word [rdx + 2], 0       ; normal version definition
    jne .invalid
    movzx r8d, word [rdx + 4]   ; vd_ndx
    cmp r8d, 2
    jb .invalid
    cmp r8d, 0x7fff
    ja .invalid
.version_next:
    mov ecx, [rdx + 16]         ; vd_next
    dec r15
    jz .version_end
    add rsi, 8
    sub rsi, r14               ; distance past current auxiliary record
    cmp rcx, rsi
    jb .invalid
    add r14, rcx
    jmp .version
.version_end:
    test ecx, ecx
    jnz .invalid
    test r8d, r8d
    jz .invalid

    mov r14, [rsp + 16]
    add r14, r12                ; current Elf64_Sym
    mov r15, [rsp + 32]
    add r15, r12                ; current Elf64_Half version index
    mov r10, [rsp + 8]
    sub r10, 21                 ; maximum symbol name offset
    mov r11, [rsp + 24]
.symbol:
    cmp [r15], r8w
    jne .symbol_next
    mov eax, [r14]              ; st_name
    cmp rax, r10
    ja .symbol_next
    lea rdx, [rbx + rax]
    mov rcx, 0x635f6f7364765f5f ; __vdso_c
    cmp [rdx], rcx
    jne .symbol_next
    mov rcx, 0x7465675f6b636f6c ; lock_get
    cmp [rdx + 8], rcx
    jne .symbol_next
    cmp dword [rdx + 16], 0x656d6974 ; time
    jne .symbol_next
    cmp byte [rdx + 20], 0
    jne .symbol_next
    cmp byte [r14 + 4], 0x12     ; STB_GLOBAL | STT_FUNC
    jne .invalid
    cmp byte [r14 + 5], 0        ; STV_DEFAULT
    jne .invalid
    movzx eax, word [r14 + 6]    ; ordinary defined section index
    test eax, eax
    jz .invalid
    cmp eax, 0xff00
    jae .invalid
    mov r9, [r14 + 8]            ; st_value in the zero-based PT_LOAD
    cmp r9, 64
    jb .invalid
    mov rax, [r14 + 16]         ; st_size
    test rax, rax
    jz .invalid
    add rax, r9
    jc .invalid
    cmp rax, r13
    ja .invalid
    mov rax, r9
    jmp .done
.symbol_next:
    add r14, 24
    add r15, 2
    dec r11
    jnz .symbol
.invalid:
    xor eax, eax
.done:
    add rsp, 56
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
