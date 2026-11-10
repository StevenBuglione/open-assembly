; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pwrite
; header: unistd.h
; prototype: ssize_t pwrite(int fd, const void *buffer, size_t count, off_t offset)
; standard: POSIX.1-2024 XSH pwrite
; deps: __errno_location
; errno: EAGAIN, EBADF, EFAULT, EFBIG, EINTR, EINVAL, EIO, ENOSPC, EOPNOTSUPP, EPERM, ESPIPE
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-filesystem-time-abi
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Write at the explicit nonnegative offset without changing the current file offset. Follow the documented Linux append support boundary.
; semantics: Reject unsupported append backing before a nonempty transfer. Zero-byte writes do not change a regular file.
; semantics: Preserve errno on success and translate Linux errors.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pwrite:function
extern __al_fcntl:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.pwrite alloc exec nowrite progbits
pwrite:
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 152
    movsxd rbx, edi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    test r14, r14
    js .invalid
    test r13, r13
    jz .plain
    mov rdi, rbx
    mov esi, 3                    ; F_GETFL
    xor edx, edx
    call __al_fcntl
    cmp rax, -4095
    jae .translate
    test eax, 0x400               ; O_APPEND
    jz .plain

    mov qword [rsp], 0
    mov rsi, rbx
    mov edi, 138                  ; __NR_fstatfs
    lea rdx, [rsp + 8]
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    cmp rax, -4095
    jae .translate
    cmp qword [rsp + 8], 0x794c7630 ; OVERLAYFS_SUPER_MAGIC
    je .unsupported

    mov [rsp + 128], r12          ; native struct iovec
    mov [rsp + 136], r13
    mov qword [rsp], 32           ; RWF_NOAPPEND
    mov rsi, rbx
    mov edi, 328                  ; __NR_pwritev2
    lea rdx, [rsp + 128]
    mov ecx, 1
    mov r8, r14                   ; full low 64 bits of the position
    xor r9d, r9d
    call __al_syscall
    cmp rax, -38                  ; ENOSYS on an older kernel
    je .unsupported
    jmp .translate

.plain:
    mov qword [rsp], 0
    mov edi, 18                   ; __NR_pwrite64
    mov rsi, rbx
    mov rdx, r12
    mov rcx, r13
    mov r8, r14
    xor r9d, r9d
    call __al_syscall
.translate:
    mov rdi, rax
    call __al_syscall_result
    add rsp, 152
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.invalid:
    mov rax, -22                  ; EINVAL
    jmp .translate
.unsupported:
    mov rax, -95                  ; EOPNOTSUPP
    jmp .translate

section .note.GNU-stack noalloc noexec nowrite progbits
