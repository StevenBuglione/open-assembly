; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: putchar_unlocked
; header: stdio.h
; prototype: int putchar_unlocked(int c)
; standard: POSIX.1-2024 XSH putchar_unlocked
; deps: -
; errno: EBADF, EIO
; mt_safe: false
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-busybox-abi
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Write c converted to unsigned char to stdout and return that byte, or EOF on failure.
; semantics: Do not acquire the stdio lock. The caller is responsible for synchronization.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global putchar_unlocked:function
extern stdout:data
extern __al_stream_write:function

section .text.putchar_unlocked alloc exec nowrite progbits
putchar_unlocked:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8
    movsxd rbx, edi
    and ebx, 255
    mov rdi, [rel stdout]
    mov [rdi + 80], bl
    lea rsi, [rdi + 80]           ; stream scratch byte
    mov edx, 1
    call __al_stream_write
    mov eax, -1
    test rdx, rdx
    jnz .done
    mov eax, ebx
.done:
    add rsp, 8
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
