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
extern __al_spawn_entry:function

section .text.posix_spawn alloc exec nowrite progbits
posix_spawn:
    sub rsp, 8
    mov qword [rsp], 0
    call __al_spawn_entry
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
