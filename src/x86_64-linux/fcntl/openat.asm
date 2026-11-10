; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: openat
; header: fcntl.h
; prototype: int openat(int dirfd, const char *path, int flags, ...)
; standard: POSIX.1-2024 XSH openat
; deps: __errno_location
; errno: EACCES, EBADF, EDQUOT, EEXIST, EFAULT, EINTR, EINVAL, EISDIR, ELOOP, EMFILE, ENAMETOOLONG, ENFILE, ENODEV, ENOENT, ENOMEM, ENOSPC, ENOTDIR, ENXIO, EOVERFLOW, EPERM, EROFS, ETXTBSY
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-file-abi
; provenance: original
; narrow_args: edi:s32, edx:s32
; variadic: true
; semantics: Resolve a relative path from dirfd or from the working directory for AT_FDCWD.
; semantics: Ignore dirfd for an absolute path.
; semantics: Return a newly opened file descriptor on success.
; semantics: Read the optional mode only for O_CREAT or the complete Linux O_TMPFILE flag pattern.
; semantics: The kernel applies the process umask and atomically sets close-on-exec when requested.
; semantics: Preserve errno on success. Translate a Linux kernel error to -1 and thread-local errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global openat:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.openat alloc exec nowrite progbits
openat:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    movsxd rdi, edi                ; directory descriptor
    movsxd rdx, edx                ; flags
    xor r8d, r8d                   ; unused mode
    test edx, 64                   ; O_CREAT
    jnz .mode
    mov eax, edx
    and eax, 4259840               ; complete O_TMPFILE flag
    cmp eax, 4259840
    jne .invoke
.mode:
    mov r8d, ecx                   ; optional mode_t
.invoke:
    mov rcx, rdx                   ; flags
    mov rdx, rsi                   ; path
    mov rsi, rdi                   ; directory descriptor
    mov edi, 257                   ; __NR_openat
    xor r9d, r9d
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
