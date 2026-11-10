; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cfgetispeed
; header: termios.h
; prototype: speed_t cfgetispeed(const struct termios *termios_p)
; standard: POSIX.1-2024 XSH cfgetispeed
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:linux-termios-uapi, reference:posix-terminal-speed
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the encoded input baud rate stored in the terminal record.
; semantics: An unset input rate follows the current output rate.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cfgetispeed:function

section .text.cfgetispeed alloc exec nowrite progbits
cfgetispeed:
    mov eax, [rdi + 8]
    shr eax, 16
    and eax, 0x100f             ; CIBAUD shifted to the base encoding
    jnz .done
    mov eax, [rdi + 8]
    and eax, 0x100f             ; CBAUD
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
