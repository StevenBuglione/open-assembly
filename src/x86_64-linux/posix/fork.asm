; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fork
; header: unistd.h
; prototype: pid_t fork(void)
; standard: POSIX.1-2024 XSH fork
; deps: _Fork, __errno_location, pthread_self
; errno: EAGAIN, ENOMEM, ENOSYS, EPERM
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-process-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Run at-fork callbacks around a Linux process snapshot with the runtime guards held.
; semantics: Return zero in the child and its process ID in the parent.
; semantics: Preserve errno on success in both processes. Return -1 and set errno on failure.
; semantics: Repair enumerated private locks and the surviving child thread bookkeeping without changing application-owned locks.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fork:function
extern _Fork:function
extern __al_atfork_dispatch:function
extern __al_atfork_state:data
extern __al_fork_child:function
extern __al_fork_guards:function
extern __al_lock:function
extern __al_panic:function
extern __al_syscall:function
extern __al_unlock:function
extern __errno_location:function

section .text.fork alloc exec nowrite progbits
fork:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    call __errno_location
    mov rbx, rax
    mov r12d, [rbx]            ; original errno
    lea rdi, [rel __al_atfork_state]
    call __al_lock
    mov r13d, [rel __al_atfork_state + 4]
    lea rdi, [rel __al_atfork_state]
    call __al_unlock
    xor edi, edi               ; prepare phase
    mov esi, r13d
    call __al_atfork_dispatch

    mov qword [rsp], 0
    mov edi, 14                ; __NR_rt_sigprocmask
    xor esi, esi               ; SIG_BLOCK
    lea rdx, [rel all_signals]
    lea rcx, [rsp + 8]
    mov r8d, 8
    xor r9d, r9d
    call __al_syscall
    test rax, rax
    jnz .mask_error

    xor edi, edi
    call __al_fork_guards
    call _Fork
    mov r14d, eax              ; PID, zero child or minus one
    mov r15d, [rbx]            ; syscall errno before cleanup
    test eax, eax
    jz .child
    mov edi, 1
    call __al_fork_guards
    jmp .restore_mask
.child:
    call __al_fork_child
    mov edi, 2
    call __al_fork_guards
.restore_mask:
    mov qword [rsp], 0
    mov edi, 14                ; __NR_rt_sigprocmask
    mov esi, 2                 ; SIG_SETMASK
    lea rdx, [rsp + 8]
    xor ecx, ecx
    mov r8d, 8
    xor r9d, r9d
    call __al_syscall
    test rax, rax
    jnz .restore_failed
    mov edi, 1                 ; parent phase on success or failure
    test r14d, r14d
    jnz .complete
    mov edi, 2                 ; child phase
    jmp .complete
.mask_error:
    mov r14d, -1
    mov r15d, eax
    neg r15d
    mov edi, 1
.complete:
    mov esi, r13d
    call __al_atfork_dispatch
    test r14d, r14d
    jns .restore_errno
    mov r12d, r15d
.restore_errno:
    mov [rbx], r12d
    mov eax, r14d
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.restore_failed:
    lea rdi, [rel mask_error]
    mov esi, 47
    call __al_panic
    ud2

section .rodata.fork alloc noexec nowrite progbits
all_signals: dq -1
mask_error: db "open-assembly: cannot restore fork signal mask", 10

section .note.GNU-stack noalloc noexec nowrite progbits
