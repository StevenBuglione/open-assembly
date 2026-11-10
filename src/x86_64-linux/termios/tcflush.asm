; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: tcflush
; header: termios.h
; prototype: int tcflush(int fd, int queue_selector)
; standard: POSIX.1-2024 XSH tcflush
; deps: __errno_location
; errno: EBADF, EINTR, EINVAL, EIO, ENOTTY
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-termios-uapi
; provenance: original
; narrow_args: edi:s32, esi:s32
; variadic: false
; semantics: Discard queued terminal input, output, or both.
; semantics: Reject an unknown operation value with EINVAL before any ioctl.
; semantics: Preserve errno on success and translate Linux errors.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global tcflush:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.tcflush alloc exec nowrite progbits
tcflush:
    sub rsp, 8
    movsxd rcx, esi
    cmp rcx, 2
    ja .invalid
    mov qword [rsp], 0
    movsxd rsi, edi
    mov edx, 0x540b             ; TCFLSH
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
