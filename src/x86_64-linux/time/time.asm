; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: time
; header: time.h
; prototype: time_t time(time_t *out)
; standard: C17 7.27.2.4
; deps: __errno_location
; errno: EFAULT, EINVAL, EOVERFLOW
; mt_safe: true
; as_safe: true
; oracles: diff:glibc, diff:musl, reference:linux-time64
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Read the realtime clock and return its whole signed seconds since the Unix epoch.
; semantics: Store the same value through out when present. Leave out unchanged on error.
; semantics: Preserve errno on success. Return time_t -1 and set errno when the clock query fails.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global time:function
extern __al_realtime_parts:function
extern __al_syscall_result:function

section .text.time alloc exec nowrite progbits
time:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8
    mov rbx, rdi
    call __al_realtime_parts
    cmp rax, -4095
    jae .error
    mov rax, rdx                  ; signed seconds
    test rbx, rbx
    jz .done
    mov [rbx], rax
    jmp .done
.error:
    mov rdi, rax
    call __al_syscall_result
.done:
    add rsp, 8
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
