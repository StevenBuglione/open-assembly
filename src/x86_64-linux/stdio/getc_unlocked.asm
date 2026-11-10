; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: getc_unlocked
; header: stdio.h
; prototype: int getc_unlocked(FILE *stream)
; standard: POSIX.1-2024 XSH getc_unlocked
; deps: -
; errno: EBADF, EIO
; mt_safe: false
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-busybox-abi
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Read one byte with getc semantics without acquiring the stdio lock.
; semantics: The caller is responsible for synchronization with other operations on the stream.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global getc_unlocked:function
extern __al_stream_read:function

section .text.getc_unlocked alloc exec nowrite progbits
getc_unlocked:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8
    mov rbx, rdi
    lea rsi, [rbx + 80]           ; stream scratch byte
    mov edx, 1
    call __al_stream_read
    test rax, rax
    jz .empty
    movzx eax, byte [rbx + 80]
    jmp .done
.empty:
    mov eax, -1
.done:
    add rsp, 8
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
