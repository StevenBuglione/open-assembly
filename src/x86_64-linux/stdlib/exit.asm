; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: exit
; header: stdlib.h
; prototype: _Noreturn void exit(int status)
; standard: C17 7.22.4.4
; deps: atexit, fflush, _exit
; errno: -
; mt_safe: false
; as_safe: false
; oracles: diff:glibc, reference:runtime-abi, reference:linux-wait-status
; provenance: original
; narrow_args: edi:s32
; variadic: false
; noreturn: true
; semantics: Invoke atexit callbacks in reverse order of registration, once per registration, before terminating.
; semantics: Callbacks may register more callbacks, which run before older pending callbacks.
; semantics: A repeated or recursive call to exit is outside the C17 contract.
; semantics: The low eight bits of status are available to the parent; the function never returns.
; semantics: After callbacks, flush all buffered stdio output. Library-created temporary files are deferred.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global exit:function
extern __al_lock:function
extern __al_unlock:function
extern _exit:function
extern fflush:function
extern __al_atexit_state:data

section .text.exit alloc exec nowrite progbits
exit:
    push rbp
    mov rbp, rsp
    push r12
    sub rsp, 8
    movsxd rdi, edi
    mov [rsp], rdi                ; status across callbacks

.next:
    lea rdi, [rel __al_atexit_state]
    call __al_lock
    lea rcx, [rel __al_atexit_state]
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
    xor edi, edi
    call fflush
    mov rdi, [rsp]
    call _exit
    ud2

section .note.GNU-stack noalloc noexec nowrite progbits
