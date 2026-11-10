; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: posix_spawn_file_actions_addopen
; header: spawn.h
; prototype: int posix_spawn_file_actions_addopen(posix_spawn_file_actions_t *restrict actions, int fd, const char *restrict path, int oflag, mode_t mode)
; standard: POSIX.1-2024 XSH posix_spawn_file_actions_addopen
; deps: strlen, memcpy, malloc, __errno_location
; errno: EBADF, EFAULT, ENOMEM
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-spawn-abi
; provenance: original
; narrow_args: esi:s32, ecx:s32, r8d:u32
; variadic: false
; semantics: Append closing the target descriptor, then opening a private copy of path with oflag and mode.
; semantics: Arrange the resulting file descriptor at fd. The target must be below the current descriptor limit.
; semantics: Return zero on success or a positive error number on failure. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global posix_spawn_file_actions_addopen:function
extern __al_spawn_append:function
extern __al_spawn_check_fd:function

section .text.posix_spawn_file_actions_addopen alloc exec nowrite progbits
posix_spawn_file_actions_addopen:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov rbx, rdi
    movsxd r12, esi
    mov r13, rdx
    test r13, r13
    jz .bad_path
    movsxd r14, ecx
    mov r15d, r8d
    mov rdi, r12
    call __al_spawn_check_fd
    test eax, eax
    jnz .done
    mov rdi, rbx
    mov esi, 2                    ; open action
    mov rdx, r12
    mov rcx, r14
    mov r8, r15
    mov r9, r13
    call __al_spawn_append
    jmp .done
.bad_path:
    mov eax, 14                   ; EFAULT
.done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
