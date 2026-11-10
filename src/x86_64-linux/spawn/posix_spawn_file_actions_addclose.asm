; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: posix_spawn_file_actions_addclose
; header: spawn.h
; prototype: int posix_spawn_file_actions_addclose(posix_spawn_file_actions_t *actions, int fd)
; standard: POSIX.1-2024 XSH posix_spawn_file_actions_addclose
; deps: malloc, __errno_location
; errno: EBADF, ENOMEM
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-spawn-abi
; provenance: original
; narrow_args: esi:s32
; variadic: false
; semantics: Append a close of the nonnegative descriptor. The descriptor need not be open at registration.
; semantics: Return zero on success or a positive error number on failure. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global posix_spawn_file_actions_addclose:function
extern __al_spawn_append:function

section .text.posix_spawn_file_actions_addclose alloc exec nowrite progbits
posix_spawn_file_actions_addclose:
    movsxd rdx, esi
    test edx, edx
    js .bad_fd
    push rbp
    mov rbp, rsp
    xor esi, esi                  ; close action
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_spawn_append
    pop rbp
    ret
.bad_fd:
    mov eax, 9                    ; EBADF
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
