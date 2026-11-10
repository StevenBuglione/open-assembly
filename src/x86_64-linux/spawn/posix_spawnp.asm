; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: posix_spawnp
; header: spawn.h
; prototype: int posix_spawnp(pid_t *restrict pid, const char *restrict file, const posix_spawn_file_actions_t *restrict actions, const posix_spawnattr_t *restrict attr, char *const argv[restrict], char *const envp[restrict])
; standard: POSIX.1-2024 XSH posix_spawnp
; deps: getenv, malloc, free, __errno_location
; errno: EACCES, EAGAIN, EBADF, EINTR, EINVAL, EIO, EMFILE, ENAMETOOLONG, ENFILE, ENOENT, ENOEXEC, ENOMEM, ENOTDIR, EPERM
; mt_safe: false
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-exec-path
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Apply attributes and file actions in the child before executing the path.
; semantics: Use the caller PATH when file has no slash and pass the supplied envp to the new image.
; semantics: Use /bin:/usr/bin when the caller PATH is unset. An empty PATH element means the current directory.
; semantics: Report ENOEXEC directly for an executable whose format the kernel cannot load.
; semantics: Publish the child ID only on success. Return positive errors and preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global posix_spawnp:function
extern __al_spawn_entry:function

section .text.posix_spawnp alloc exec nowrite progbits
posix_spawnp:
    sub rsp, 8
    mov qword [rsp], 1
    call __al_spawn_entry
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
