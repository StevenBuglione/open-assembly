; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: readlink
; header: unistd.h
; prototype: ssize_t readlink(const char *restrict path, char *restrict buf, size_t size)
; standard: POSIX.1-2024 XSH readlink
; deps: __errno_location
; errno: EACCES, EFAULT, EINVAL, EIO, ELOOP, ENAMETOOLONG, ENOENT, ENOMEM, ENOTDIR
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-busybox-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Read up to size bytes of a symbolic-link target without adding a terminating NUL.
; semantics: Return the number of bytes placed in buf and preserve errno on success.
; semantics: Return -1 and set errno when the Linux operation fails.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global readlink:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.readlink alloc exec nowrite progbits
readlink:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov rcx, rdx                   ; size
    mov rdx, rsi                   ; buffer
    mov rsi, rdi                   ; path
    mov edi, 89                    ; __NR_readlink
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
