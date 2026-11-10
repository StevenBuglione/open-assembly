; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: tcgetsid
; header: termios.h
; prototype: pid_t tcgetsid(int fd)
; standard: POSIX.1-2024 XSH tcgetsid
; deps: __errno_location
; errno: EBADF, EINTR, EIO, ENOTTY
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-termios-uapi
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Return the session ID associated with the terminal when the kernel allows the query.
; semantics: Preserve errno on success and translate Linux errors.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global tcgetsid:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.tcgetsid alloc exec nowrite progbits
tcgetsid:
    sub rsp, 24
    mov qword [rsp], 0
    mov dword [rsp + 8], 0      ; initialized kernel session ID slot
    movsxd rsi, edi
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 16                 ; __NR_ioctl
    mov edx, 0x5429             ; TIOCGSID
    lea rcx, [rsp + 8]
    call __al_syscall
    cmp rax, -4095
    jae .error
    mov eax, [rsp + 8]
    jmp .done
.error:
    mov rdi, rax
    call __al_syscall_result
.done:
    add rsp, 24
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
