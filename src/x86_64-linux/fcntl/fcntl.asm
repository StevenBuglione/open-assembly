; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fcntl
; header: fcntl.h
; prototype: int fcntl(int fd, int command, ...)
; standard: POSIX.1-2024 XSH fcntl
; deps: __errno_location
; errno: EACCES, EAGAIN, EBADF, EDEADLK, EFAULT, EINTR, EINVAL, EMFILE, ENOLCK, EOVERFLOW, EPERM, ESRCH
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-fcntl-abi
; provenance: original
; narrow_args: edi:s32, esi:s32
; variadic: true
; semantics: Dispatch the selected Linux descriptor, status flag, owner, record lock, and pipe size commands.
; semantics: Select a no-argument, promoted int, or pointer argument by command before forwarding to Linux.
; semantics: Use the LP64 flock layout for process and open-file-description record locks.
; semantics: Preserve successful negative process group IDs for F_GETOWN. Use F_GETOWN_EX when the result would equal the error sentinel.
; semantics: Return the command result and preserve errno on success. Return -1 with errno for errors.
; semantics: Report EINVAL for an unrecognized command without consuming an argument.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fcntl:function
extern __al_fcntl:function
extern __al_fcntl_owner:function
extern __al_syscall_result:function

section .text.fcntl alloc exec nowrite progbits
fcntl:
    sub rsp, 8
    movsxd rdi, edi
    movsxd rsi, esi
    cmp esi, 9                     ; F_GETOWN
    je .owner
    cmp esi, 8                     ; F_SETOWN
    je .integer
    cmp esi, 7                     ; F_SETLKW
    ja .extended
    cmp esi, 5                     ; F_GETLK through F_SETLKW
    jae .invoke
    cmp esi, 3                     ; F_GETFL
    je .no_argument
    cmp esi, 1                     ; F_GETFD
    je .no_argument
    jmp .integer                   ; F_DUPFD, F_SETFD, F_SETFL

.extended:
    cmp esi, 15                    ; F_SETOWN_EX
    je .invoke
    cmp esi, 16                    ; F_GETOWN_EX
    je .invoke
    cmp esi, 36                    ; F_OFD_GETLK through F_OFD_SETLKW
    jb .invalid
    cmp esi, 38
    jbe .invoke
    cmp esi, 1030                  ; F_DUPFD_CLOEXEC
    je .integer
    cmp esi, 1031                  ; F_SETPIPE_SZ
    je .integer
    cmp esi, 1032                  ; F_GETPIPE_SZ
    jne .invalid

.no_argument:
    xor edx, edx
    jmp .invoke

.integer:
    movsxd rdx, edx
.invoke:
    call __al_fcntl
    mov rdi, rax
.translate:
    call __al_syscall_result
.done:
    add rsp, 8
    ret

.owner:
    call __al_fcntl_owner
    jmp .done

.invalid:
    mov rdi, -22                   ; EINVAL
    jmp .translate

section .note.GNU-stack noalloc noexec nowrite progbits
