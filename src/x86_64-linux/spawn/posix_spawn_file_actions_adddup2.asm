; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: posix_spawn_file_actions_adddup2
; header: spawn.h
; prototype: int posix_spawn_file_actions_adddup2(posix_spawn_file_actions_t *actions, int fd, int newfd)
; standard: POSIX.1-2024 XSH posix_spawn_file_actions_adddup2
; deps: malloc, __errno_location
; errno: EBADF, ENOMEM
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-spawn-abi
; provenance: original
; narrow_args: esi:s32, edx:s32
; variadic: false
; semantics: Append duplication from fd onto newfd in the child. Same-descriptor duplication clears close-on-exec.
; semantics: Both descriptor numbers must be nonnegative and below the current open descriptor limit.
; semantics: Return zero on success or a positive error number on failure. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global posix_spawn_file_actions_adddup2:function
extern __al_spawn_append:function
extern __al_spawn_check_fd:function

section .text.posix_spawn_file_actions_adddup2 alloc exec nowrite progbits
posix_spawn_file_actions_adddup2:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 8
    mov rbx, rdi
    movsxd r12, esi
    movsxd r13, edx
    test r12d, r12d
    js .bad_fd
    test r13d, r13d
    js .bad_fd
    mov rdi, r12
    cmp r13, r12
    jbe .check_limit
    mov rdi, r13
.check_limit:
    call __al_spawn_check_fd
    test eax, eax
    jnz .done
    mov rdi, rbx
    mov esi, 1                    ; dup2 action
    mov rdx, r12
    mov rcx, r13
    xor r8d, r8d
    xor r9d, r9d
    call __al_spawn_append
    jmp .done
.bad_fd:
    mov eax, 9                    ; EBADF
.done:
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
