; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: tcflow
; header: termios.h
; prototype: int tcflow(int fd, int action)
; standard: POSIX.1-2024 XSH tcflow
; deps: __errno_location
; errno: EBADF, EINTR, EINVAL, EIO, ENOTTY
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-termios-uapi
; provenance: original
; narrow_args: edi:s32, esi:s32
; variadic: false
; semantics: Suspend or resume terminal input or output using the selected action.
; semantics: Reject an unknown operation value with EINVAL before any ioctl.
; semantics: Preserve errno on success and translate Linux errors.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global tcflow:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.tcflow alloc exec nowrite progbits
tcflow:
    sub rsp, 8
    movsxd rcx, esi
    cmp rcx, 3
    ja .invalid
    mov qword [rsp], 0
    movsxd rsi, edi
    mov edx, 0x540a             ; TCXONC
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
