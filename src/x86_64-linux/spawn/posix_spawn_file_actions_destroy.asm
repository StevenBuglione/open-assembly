; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: posix_spawn_file_actions_destroy
; header: spawn.h
; prototype: int posix_spawn_file_actions_destroy(posix_spawn_file_actions_t *actions)
; standard: POSIX.1-2024 XSH posix_spawn_file_actions_destroy
; deps: free
; errno: -
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-spawn-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Release the initialized action object and its copied paths.
; semantics: Return zero on success or a positive error number on failure. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global posix_spawn_file_actions_destroy:function
extern free:function

section .text.posix_spawn_file_actions_destroy alloc exec nowrite progbits
posix_spawn_file_actions_destroy:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov rbx, [rdi]
    mov qword [rdi], 0
    mov qword [rdi + 8], 0
.next:
    test rbx, rbx
    jz .done
    mov r12, [rbx]
    mov rdi, rbx
    call free
    mov rbx, r12
    jmp .next
.done:
    xor eax, eax
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
