; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: cfgetospeed
; header: termios.h
; prototype: speed_t cfgetospeed(const struct termios *termios_p)
; standard: POSIX.1-2024 XSH cfgetospeed
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:linux-termios-uapi, reference:posix-terminal-speed
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Return the encoded output baud rate stored in the terminal record.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global cfgetospeed:function

section .text.cfgetospeed alloc exec nowrite progbits
cfgetospeed:
    mov eax, [rdi + 8]
    and eax, 0x100f             ; CBAUD
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
