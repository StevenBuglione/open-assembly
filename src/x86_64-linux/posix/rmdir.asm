; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: rmdir
; header: unistd.h
; prototype: int rmdir(const char *path)
; standard: POSIX.1-2024 XSH rmdir
; deps: __errno_location
; errno: EACCES, EBUSY, EFAULT, EINVAL, ELOOP, ENAMETOOLONG, ENOENT, ENOMEM, ENOTDIR, ENOTEMPTY, EPERM, EROFS
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-file-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Remove an empty directory entry selected by path.
; semantics: Return zero on success.
; semantics: Preserve errno on success. Translate a Linux kernel error to -1 and thread-local errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global rmdir:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.rmdir alloc exec nowrite progbits
rmdir:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov rsi, rdi                   ; path
    mov edi, 84                    ; __NR_rmdir
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
