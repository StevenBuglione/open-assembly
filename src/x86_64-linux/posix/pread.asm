; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pread
; header: unistd.h
; prototype: ssize_t pread(int fd, void *buffer, size_t count, off_t offset)
; standard: POSIX.1-2024 XSH pread
; deps: __errno_location
; errno: EAGAIN, EBADF, EFAULT, EINTR, EINVAL, EIO, EISDIR, ESPIPE
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-filesystem-time-abi
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Read at the explicit signed file offset without changing the current file offset.
; semantics: Preserve errno on success and translate Linux errors.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pread:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.pread alloc exec nowrite progbits
pread:
    sub rsp, 8
    mov qword [rsp], 0
    mov r8, rcx
    mov rcx, rdx
    mov rdx, rsi
    movsxd rsi, edi
    xor r9d, r9d
    mov edi, 17                  ; __NR_pread64
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
