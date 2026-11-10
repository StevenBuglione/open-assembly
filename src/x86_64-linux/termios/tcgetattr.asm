; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: tcgetattr
; header: termios.h
; prototype: int tcgetattr(int fd, struct termios *termios_p)
; standard: POSIX.1-2024 XSH tcgetattr
; deps: __errno_location
; errno: EBADF, EFAULT, EINTR, EIO, ENOTTY
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-termios-uapi
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Read current Linux terminal attributes using the x86-64 TCGETS record.
; semantics: Return zero and preserve errno on success. Return -1 and set errno on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global tcgetattr:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.tcgetattr alloc exec nowrite progbits
tcgetattr:
    sub rsp, 8
    mov qword [rsp], 0
    mov rcx, rsi
    movsxd rsi, edi
    mov edx, 0x5401             ; TCGETS
    mov edi, 16                 ; __NR_ioctl
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
