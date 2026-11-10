; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: read
; header: unistd.h
; prototype: ssize_t read(int fd, void *buf, size_t count)
; standard: POSIX.1-2024 XSH read
; deps: __errno_location
; errno: EAGAIN, EBADF, EFAULT, EINTR, EINVAL, EIO, EISDIR
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, reference:linux-read
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Perform one Linux read of up to count bytes; return the byte count, including a short result or zero at EOF.
; semantics: Do not modify errno on success or modify the buffer beyond the bytes transferred.
; semantics: Return -1 and set errno to the positive kernel error on failure; do not retry EINTR.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global read:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.read alloc exec nowrite progbits
read:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov qword [rsp], 0
    mov rcx, rdx                   ; count
    mov rdx, rsi                   ; buffer
    movsxd rsi, edi                ; fd
    mov edi, 0                     ; __NR_read
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 16
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
