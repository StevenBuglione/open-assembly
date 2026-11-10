; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cfsetispeed
; header: termios.h
; prototype: int cfsetispeed(struct termios *termios_p, speed_t speed)
; standard: POSIX.1-2024 XSH cfsetispeed
; deps: __errno_location
; errno: EINVAL
; mt_safe: true
; as_safe: true
; oracles: reference:linux-termios-uapi, reference:posix-terminal-speed
; provenance: original
; narrow_args: esi:u32
; variadic: false
; semantics: Set the encoded input baud rate without changing unrelated terminal flags.
; semantics: B0 follows the output rate.
; semantics: Unsupported speed codes leave the record unchanged and return -1 with EINVAL.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cfsetispeed:function
extern __al_syscall_result:function

section .text.cfsetispeed alloc exec nowrite progbits
cfsetispeed:
    mov esi, esi
    cmp esi, 15                ; B0 through B38400
    jbe .set
    cmp esi, 0x1001            ; B57600
    jb .invalid
    cmp esi, 0x100f            ; B4000000
    ja .invalid
.set:
    mov eax, [rdi + 8]
    shl esi, 16
    and eax, 0xeff0ffff     ; clear CIBAUD
    or eax, esi
    mov [rdi + 8], eax
    xor eax, eax
    ret
.invalid:
    sub rsp, 8
    mov rdi, -22               ; EINVAL
    call __al_syscall_result
    add rsp, 8
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
