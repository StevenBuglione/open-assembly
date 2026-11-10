; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: readdir
; header: dirent.h
; prototype: struct dirent *readdir(DIR *dirp)
; standard: POSIX.1-2024 XSH readdir
; deps: __errno_location
; errno: EBADF, EIO, ENOENT, ENOTDIR
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-file-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the next validated directory entry in storage owned by the stream.
; semantics: The returned record can be overwritten by a later call on the same stream.
; semantics: Return a null pointer at end of directory without changing errno.
; semantics: On failure return a null pointer and set errno. Report malformed kernel records as EIO.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global readdir:function
extern __al_lock:function
extern __al_unlock:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.readdir alloc exec nowrite progbits
readdir:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    sub rsp, 16
    mov rbx, rdi
    xor r12d, r12d               ; null result for EOF or failure
    call __al_lock
    mov rax, [rbx + 8]           ; cursor
    mov rdx, [rbx + 16]          ; available record bytes
    cmp rax, rdx
    jb .record

    mov qword [rsp], 0
    mov edi, 217                  ; __NR_getdents64
    movsxd rsi, dword [rbx + 4]
    lea rdx, [rbx + 312]
    mov ecx, 4096
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .kernel_error
    test rax, rax
    jz .unlock
    cmp rax, 4096
    ja .malformed
    mov [rbx + 16], rax
    mov qword [rbx + 8], 0
    mov rdx, rax
    xor eax, eax

.record:
    sub rdx, rax                  ; bytes left from this record
    cmp rdx, 20                  ; fixed fields and at least one name byte
    jb .malformed
    lea r8, [rbx + rax + 312]
    movzx esi, word [r8 + 16]
    cmp rsi, 20
    jb .malformed
    cmp rsi, rdx
    ja .malformed
    lea r9, [rsi - 19]           ; name extent within the raw record
    xor ecx, ecx
.find_nul:
    cmp rcx, r9
    jae .malformed
    cmp rcx, 255
    ja .malformed
    cmp byte [r8 + rcx + 19], 0
    je .publish
    inc rcx
    jmp .find_nul

.publish:
    add rax, rsi
    mov [rbx + 8], rax
    lea r12, [rbx + 32]
    mov rax, [r8]
    mov [r12], rax
    mov rax, [r8 + 8]
    mov [r12 + 8], rax
    mov [r12 + 16], si
    mov al, [r8 + 18]
    mov [r12 + 18], al
.copy_name:
    mov al, [r8 + rcx + 19]
    mov [r12 + rcx + 19], al
    dec rcx
    jns .copy_name
    jmp .unlock

.malformed:
    mov rax, [rbx + 16]
    mov [rbx + 8], rax           ; discard the rest of the invalid batch
    mov rax, -5                   ; EIO
.kernel_error:
    mov rdi, rax
    call __al_syscall_result
.unlock:
    mov rdi, rbx
    call __al_unlock
    mov rax, r12
    add rsp, 16
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
