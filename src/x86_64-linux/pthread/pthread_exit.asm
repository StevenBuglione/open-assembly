; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: pthread_exit
; header: pthread.h
; prototype: _Noreturn void pthread_exit(void *result)
; standard: POSIX.1-2024 XSH pthread_exit
; deps: pthread_self, exit
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-thread-lifecycle
; provenance: original
; narrow_args: -
; variadic: false
; noreturn: true
; semantics: Terminate the calling thread and publish result to any valid joining thread.
; semantics: Release unfinished one-time initialization controls before cleanup.
; semantics: Run the current thread's thread-specific destructors before result publication.
; semantics: Preserve other live threads. When this is the last thread, run process exit with status zero.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global pthread_exit:function
global __al_thread_count:data
extern pthread_self:function
extern __al_tsd_destruct:function
extern __al_once_reset:function
extern exit:function
extern __al_syscall:function
extern __al_thread_unmap_exit:function
extern __al_panic:function

section .text.pthread_exit alloc exec nowrite progbits
pthread_exit:
    push rbx
    push r12
    sub rsp, 24
    mov r12, rdi
    call pthread_self
    mov rbx, rax
    mov rdi, rbx
    call __al_once_reset
    mov rdi, rbx
    call __al_tsd_destruct
    mov [rbx + 0x78], r12
    mov eax, -1
    lock xadd dword [rel __al_thread_count], eax
    cmp eax, 1
    je .last

    xor eax, eax                  ; open
    mov edx, 1                    ; exiting open
    lock cmpxchg dword [rbx + 0x74], edx
    jz .thread_exit
    cmp eax, 2                    ; claimed
    je .thread_exit
    cmp eax, 3                    ; detached
    jne .failure

    mov qword [rsp], 0
    mov qword [rsp + 8], -1
    mov edi, 14                   ; __NR_rt_sigprocmask
    mov esi, 2                    ; SIG_SETMASK
    lea rdx, [rsp + 8]
    xor ecx, ecx
    mov r8d, 8
    xor r9d, r9d
    call __al_syscall
    test rax, rax
    jnz .failure
    mov edi, 218                  ; __NR_set_tid_address
    xor esi, esi                  ; no kernel write to the released TLS
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    test rax, rax
    jle .failure
    mov rdi, [rbx + 0x50]
    mov rsi, [rbx + 0x58]
    mov rdx, [rbx + 0x60]
    mov rcx, [rbx + 0x68]
    call __al_thread_unmap_exit
    ud2
.thread_exit:
    mov qword [rsp], 0
    mov edi, 60                   ; __NR_exit, this thread only
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    jmp .failure
.last:
    xor edi, edi
    call exit
    ud2
.failure:
    lea rdi, [rel failure]
    mov esi, 36
    call __al_panic
    ud2

section .rodata.pthread_exit alloc noexec nowrite progbits
failure: db "open-assembly: cannot exit a thread", 10

section .data.pthread_exit alloc noexec write progbits align=4
__al_thread_count: dd 1

section .note.GNU-stack noalloc noexec nowrite progbits
