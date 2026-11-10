; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: unlink
; header: unistd.h
; prototype: int unlink(const char *path)
; standard: POSIX.1-2024 XSH unlink
; deps: __errno_location
; errno: EACCES, EBUSY, EFAULT, EIO, EISDIR, ELOOP, ENAMETOOLONG, ENOENT, ENOMEM, ENOTDIR, EPERM, EROFS
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-file-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Remove the named directory entry.
; semantics: Existing open descriptors continue to refer to their original open file descriptions.
; semantics: Return zero on success.
; semantics: Preserve errno on success. Translate a Linux kernel error to -1 and thread-local errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global unlink:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.unlink alloc exec nowrite progbits
unlink:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov rsi, rdi                   ; path
    mov edi, 87                    ; __NR_unlink
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
