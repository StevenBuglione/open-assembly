; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: tcsendbreak
; header: termios.h
; prototype: int tcsendbreak(int fd, int duration)
; standard: POSIX.1-2024 XSH tcsendbreak
; deps: __errno_location
; errno: EBADF, EINTR, EIO, ENOTTY
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-termios-uapi
; provenance: original
; narrow_args: edi:s32, esi:s32
; variadic: false
; semantics: Request the Linux default serial break for a nonpositive duration.
; semantics: Request a positive duration in deciseconds, capped at INT_MAX divided by 100.
; semantics: Preserve errno on success and translate Linux errors.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global tcsendbreak:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.tcsendbreak alloc exec nowrite progbits
tcsendbreak:
    sub rsp, 8
    mov qword [rsp], 0
    movsxd rcx, esi
    movsxd rsi, edi
    test rcx, rcx
    jle .default_duration
    mov edx, 0x5425             ; TCSBRKP with positive deciseconds
    cmp ecx, 21474836           ; maximum representable signed milliseconds
    jbe .request
    mov ecx, 21474836
    jmp .request
.default_duration:
    mov edx, 0x5409             ; TCSBRK default break
    xor ecx, ecx
.request:
    mov edi, 16                 ; __NR_ioctl
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    mov rdi, rax
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
