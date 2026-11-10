; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: tcdrain
; header: termios.h
; prototype: int tcdrain(int fd)
; standard: POSIX.1-2024 XSH tcdrain
; deps: __errno_location
; errno: EBADF, EINTR, EIO, ENOTTY
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-termios-uapi
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Wait for queued terminal output to be transmitted without requesting a break.
; semantics: Preserve errno on success and translate Linux errors.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global tcdrain:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.tcdrain alloc exec nowrite progbits
tcdrain:
    sub rsp, 8
    mov qword [rsp], 0
    movsxd rsi, edi
    mov edx, 0x5409             ; TCSBRK
    mov ecx, 1                 ; drain without break
    mov edi, 16                 ; __NR_ioctl
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
