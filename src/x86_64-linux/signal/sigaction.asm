; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: sigaction
; header: signal.h
; prototype: int sigaction(int sig, const struct sigaction *restrict act, struct sigaction *restrict oldact)
; standard: POSIX.1-2024 XSH sigaction
; deps: __errno_location
; errno: EFAULT, EINVAL
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-signal-abi
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Install a signal disposition when act is present and publish the prior disposition when oldact is present.
; semantics: Marshal the public mask and flags to the Linux x86-64 kernel record and use the runtime signal restorer.
; semantics: For an old disposition, clear reserved bytes, clear the private restorer flag and field, and expand the mask.
; semantics: The oldact record remains untouched on failure. Return zero and preserve errno on success.
; semantics: Use SA_SIGINFO for three-argument dispatch, and pass the Linux signal metadata and machine context.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global sigaction:function
extern __al_syscall:function
extern __al_syscall_result:function
extern __al_rt_sigreturn:function
extern __al_sigset_publish:function

section .text.sigaction alloc exec nowrite progbits
sigaction:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 88
    mov rbx, rdx                  ; public old action
    movsxd r10, edi               ; signal number
    mov qword [rsp], 0
    mov r8d, 8                    ; kernel mask width
    xor r9d, r9d
    test rsi, rsi
    jz .query

    mov rax, [rsi]
    mov [rsp + 8], rax            ; kernel handler
    mov eax, [rsi + 136]
    or eax, 0x04000000            ; SA_RESTORER
    mov [rsp + 16], rax           ; kernel flags
    lea rax, [rel __al_rt_sigreturn]
    mov [rsp + 24], rax           ; kernel restorer
    mov rax, [rsi + 8]
    mov [rsp + 32], rax           ; kernel mask
    mov rsi, r10
    mov edi, 13                   ; __NR_rt_sigaction
    lea rcx, [rsp + 40]           ; old kernel action
    lea rdx, [rsp + 8]            ; new kernel action
    call __al_syscall
    jmp .result
.query:
    mov rsi, r10
    xor edx, edx
    mov edi, 13
    lea rcx, [rsp + 40]
    call __al_syscall
.result:
    cmp rax, -4095
    jae .error
    test rbx, rbx
    jz .done
    mov rax, [rsp + 40]
    mov [rbx], rax
    mov edx, [rsp + 48]
    and edx, 0xfbffffff           ; keep public flags and clear SA_RESTORER
    mov [rbx + 136], rdx          ; also clear public alignment padding
    mov qword [rbx + 144], 0
    lea rdi, [rbx + 8]
    mov rsi, [rsp + 64]
    call __al_sigset_publish
    jmp .done
.error:
    mov rdi, rax
    call __al_syscall_result
.done:
    add rsp, 88
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
