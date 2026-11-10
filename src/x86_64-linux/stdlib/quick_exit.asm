; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: quick_exit
; header: stdlib.h
; prototype: _Noreturn void quick_exit(int status)
; standard: C17 7.22.4.7
; deps: _Exit, at_quick_exit
; errno: -
; mt_safe: true
; as_safe: false
; oracles: reference:c17-quick-exit, diff:glibc, diff:musl
; provenance: original
; narrow_args: edi:s32
; variadic: false
; noreturn: true
; semantics: Invoke registered quick termination callbacks in reverse registration order.
; semantics: Run callbacks registered by the active callback before older pending callbacks.
; semantics: Finish with _Exit and the supplied status. Leave ordinary exit callbacks and stdio flushing to normal termination.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global quick_exit:function
extern __al_lock:function
extern __al_unlock:function
extern _Exit:function
extern __al_quick_exit_state:data

section .text.quick_exit alloc exec nowrite progbits
quick_exit:
    push rbp
    mov rbp, rsp
    push r12
    sub rsp, 8
    movsxd rdi, edi
    mov [rsp], rdi                ; status across callbacks

.next:
    lea rdi, [rel __al_quick_exit_state]
    call __al_lock
    lea rcx, [rel __al_quick_exit_state]
    mov eax, [rcx + 4]
    test eax, eax
    jz .finished
    dec eax
    mov [rcx + 4], eax
    mov r12, [rcx + rax*8 + 8]
    mov qword [rcx + rax*8 + 8], 0
    mov rdi, rcx
    call __al_unlock

    ; Only the popped void(void) callback is called. Its slot is available
    ; before it runs, so registration from the callback may reuse it.
    mov rax, r12
    call rax
    jmp .next

.finished:
    mov rdi, rcx
    call __al_unlock
    mov rdi, [rsp]
    call _Exit
    ud2

section .note.GNU-stack noalloc noexec nowrite progbits
