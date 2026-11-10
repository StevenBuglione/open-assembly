; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: chmod
; header: sys/stat.h
; prototype: int chmod(const char *path, mode_t mode)
; standard: POSIX.1-2024 XSH chmod
; deps: __errno_location
; errno: EACCES, EFAULT, EIO, ELOOP, ENAMETOOLONG, ENOENT, ENOMEM, ENOTDIR, EPERM, EROFS
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-busybox-abi
; provenance: original
; narrow_args: esi:u32
; variadic: false
; semantics: Apply the supplied mode to the file reached by path, including normal symlink following.
; semantics: Let the Linux kernel enforce filesystem, mode, ownership, and permission rules.
; semantics: Return zero on success and preserve errno. Return -1 and set errno on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global chmod:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.chmod alloc exec nowrite progbits
chmod:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov edx, esi                   ; mode
    mov rsi, rdi                   ; path
    mov edi, 90                    ; __NR_chmod
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
