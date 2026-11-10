; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: posix_spawn
; header: spawn.h
; prototype: int posix_spawn(pid_t *restrict pid, const char *restrict path, const posix_spawn_file_actions_t *restrict actions, const posix_spawnattr_t *restrict attr, char *const argv[restrict], char *const envp[restrict])
; standard: POSIX.1-2024 XSH posix_spawn
; deps: malloc, free, __errno_location
; errno: EACCES, EAGAIN, EBADF, EINTR, EINVAL, EIO, EMFILE, ENFILE, ENOENT, ENOEXEC, ENOMEM, EPERM
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-spawn-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Execute the explicit path in a child with the supplied argument and environment vectors.
; semantics: Apply selected attributes, then file actions exactly once in registration order, then Linux close-on-exec.
; semantics: Supported attributes select real IDs, a process group, default dispositions, and a signal mask.
; semantics: A null actions or attr pointer selects the defaults for that category.
; semantics: On success publish the child ID through a nonnull pid pointer. Leave pid untouched on failure.
; semantics: Report pre-exec errors through a private close-on-exec handshake and reap a failed child.
; semantics: Return zero on success or a positive error number on failure. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global posix_spawn:function
extern __errno_location:function
extern malloc:function
extern free:function
extern __al_spawn_run:function

section .text.posix_spawn alloc exec nowrite progbits
posix_spawn:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 48
    mov [rsp], rdi                ; pid output
    mov [rsp + 8], rsi            ; executable path
    mov [rsp + 16], rdx           ; optional file actions
    mov [rsp + 24], rcx           ; optional attributes
    mov [rsp + 32], r8            ; argv
    mov [rsp + 40], r9            ; envp
    call __errno_location
    mov r12, rax
    mov r13d, [rax]
    mov edi, 128                  ; parent-owned workspace, inherited by child
    call malloc
    test rax, rax
    jz .no_memory
    mov rbx, rax
    mov rax, [rsp + 8]
    mov [rbx], rax
    mov rax, [rsp + 32]
    mov [rbx + 8], rax
    mov rax, [rsp + 40]
    mov [rbx + 16], rax
    mov rax, [rsp + 16]
    test rax, rax
    jz .actions_ready
    mov rax, [rax]                ; first action
.actions_ready:
    mov [rbx + 24], rax
    mov rax, [rsp + 24]
    test rax, rax
    jz .attributes_ready
    mov rax, [rax]                ; attribute state
.attributes_ready:
    mov [rbx + 32], rax
    mov rax, [rsp]
    mov [rbx + 40], rax
    mov rdi, rbx
    call __al_spawn_run
    mov r14d, eax
    mov rdi, rbx
    call free
    jmp .restore
.no_memory:
    mov r14d, 12                  ; ENOMEM
.restore:
    mov [r12], r13d
    mov eax, r14d
    add rsp, 48
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
