; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: isatty
; header: unistd.h
; prototype: int isatty(int fd)
; standard: POSIX.1-2024 XSH isatty
; deps: __errno_location
; errno: EBADF, ENOTTY
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-busybox-abi
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Return one when the descriptor accepts a Linux terminal-attribute query.
; semantics: Return zero on failure and set errno from the kernel result.
; semantics: Preserve errno on success. Use a per-call kernel result record.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global isatty:function
extern __al_syscall:function
extern __al_syscall_result:function

section .text.isatty alloc exec nowrite progbits
isatty:
    push rbp
    mov rbp, rsp
    sub rsp, 80
    mov qword [rsp], 0
    movsxd rsi, edi
    xor r8d, r8d
    xor r9d, r9d
    mov edi, 16                    ; __NR_ioctl
    mov edx, 0x5401                ; TCGETS
    lea rcx, [rsp + 8]
    call __al_syscall
    cmp rax, -4095
    jae .error
    mov eax, 1
    jmp .done
.error:
    mov rdi, rax
    call __al_syscall_result
    xor eax, eax
.done:
    add rsp, 80
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
