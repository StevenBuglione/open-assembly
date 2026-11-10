; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: open
; header: fcntl.h
; prototype: int open(const char *path, int flags, ...)
; standard: POSIX.1-2024 XSH open
; deps: __errno_location
; errno: EACCES, EBADF, EDQUOT, EEXIST, EFAULT, EINTR, EINVAL, EISDIR, ELOOP, EMFILE, ENAMETOOLONG, ENFILE, ENODEV, ENOENT, ENOMEM, ENOSPC, ENOTDIR, ENXIO, EOVERFLOW, EPERM, EROFS, ETXTBSY
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-file-abi
; provenance: original
; narrow_args: esi:s32
; variadic: true
; semantics: Use the process working directory for a relative path.
; semantics: Return a newly opened file descriptor on success.
; semantics: Read the optional mode only for O_CREAT or the complete Linux O_TMPFILE flag pattern.
; semantics: The kernel applies the process umask and atomically sets close-on-exec when requested.
; semantics: Preserve errno on success. Translate a Linux kernel error to -1 and thread-local errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global open:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.open alloc exec nowrite progbits
open:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    movsxd rcx, esi                ; flags
    xor r8d, r8d                   ; unused mode
    test ecx, 64                   ; O_CREAT
    jnz .mode
    mov eax, ecx
    and eax, 4259840               ; complete O_TMPFILE flag
    cmp eax, 4259840
    jne .invoke
.mode:
    mov r8d, edx                   ; optional mode_t
.invoke:
    mov rdx, rdi                   ; path
    mov rsi, -100                  ; AT_FDCWD
    mov edi, 257                   ; __NR_openat
    xor r9d, r9d
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
