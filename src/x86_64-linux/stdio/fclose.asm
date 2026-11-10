; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: fclose
; header: stdio.h
; prototype: int fclose(FILE *stream)
; standard: C17 7.21.5.1
; deps: close, free
; errno: EBADF, EIO
; mt_safe: true
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:phase4-stdio
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Flush pending output and close the underlying descriptor, even if the flush fails.
; semantics: On success return zero. On error return EOF. Release library-owned stream memory.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global fclose:function
extern __al_stream_lock:function
extern __al_stream_unlock_all:function
extern __al_stream_unpin:function
extern __al_stream_close:function

section .text.fclose alloc exec nowrite progbits
fclose:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    mov rbx, rdi
    call __al_stream_lock
    mov rdi, rbx
    xor esi, esi
    call __al_stream_close
    mov r12d, eax
    mov rdi, rbx
    call __al_stream_unlock_all
    mov rdi, rbx
    mov esi, 1
    call __al_stream_unpin
    mov eax, r12d
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
