; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fileno
; header: stdio.h
; prototype: int fileno(FILE *stream)
; standard: POSIX.1-2024 XSH fileno
; deps: __errno_location
; errno: EBADF
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:stream-ownership
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Read the stream's associated descriptor under recursive stream ownership.
; semantics: Preserve stream position, buffered contents, status indicators, and errno on success.
; semantics: Return -1 with EBADF when the stream has no associated descriptor.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fileno:function
extern __al_stream_lock:function
extern __al_stream_unlock:function
extern __al_stdio_errno:function

section .text.fileno alloc exec nowrite progbits
fileno:
    push rbx
    push r12
    sub rsp, 8
    mov rbx, rdi
    call __al_stream_lock
    mov r12, [rbx]
    mov rdi, rbx
    call __al_stream_unlock
    test r12, r12
    js .no_descriptor
    mov eax, r12d
    jmp .done

.no_descriptor:
    mov edi, 9                     ; EBADF
    call __al_stdio_errno
.done:
    add rsp, 8
    pop r12
    pop rbx
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
