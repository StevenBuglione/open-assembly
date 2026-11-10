; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: tcsetattr
; header: termios.h
; prototype: int tcsetattr(int fd, int optional_actions, const struct termios *termios_p)
; standard: POSIX.1-2024 XSH tcsetattr
; deps: __errno_location
; errno: EBADF, EFAULT, EINTR, EINVAL, EIO, ENOTTY
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-termios-uapi
; provenance: original
; narrow_args: edi:s32, esi:s32
; variadic: false
; semantics: Apply Linux terminal attributes immediately, after output drains, or after drain and input flush.
; semantics: Reject an unknown action with EINVAL before any ioctl.
; semantics: Return zero and preserve errno on success. Return -1 and set errno on failure.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global tcsetattr:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.tcsetattr alloc exec nowrite progbits
tcsetattr:
    sub rsp, 8
    movsxd rsi, esi
    cmp rsi, 2
    ja .invalid
    mov qword [rsp], 0
    mov rcx, rdx
    lea rdx, [rsi + 0x5402]     ; TCSETS, TCSETSW, TCSETSF
    movsxd rsi, edi
    mov edi, 16                 ; __NR_ioctl
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    mov rdi, rax
    jmp .result
.invalid:
    mov rdi, -22                ; EINVAL
.result:
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
