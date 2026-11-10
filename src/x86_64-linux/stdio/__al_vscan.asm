; Original byte and wide scanf interpreter. rdi = input, rsi = format,
; rdx = va_list. Source kind rcx is 0 byte string, 1 byte stream,
; 2 wide string or 3 wide stream.
bits 64
default rel

global __al_vscan:function
extern __al_stream_lock:function
extern __al_stream_unlock:function
extern __al_lock:function
extern __al_unlock:function
extern __al_stdio_errno:function
extern __al_fmt_decimal:function
extern __al_scan_peek:function
extern __al_scan_take:function
extern __al_scan_space:function
extern __al_scan_set:function
extern __al_scan_chars:function
extern __al_scan_number:function
extern __al_scan_store:function
extern __al_scan_float:function
extern __al_va_next:function
extern isspace:function
extern iswspace:function
extern __al_fmt_unit:function
extern __al_stream_orient:function
extern __al_scan_wset:function
extern __al_scan_wchars:function
extern malloc:function
extern free:function
extern memcpy:function

section .text.__al_vscan alloc exec nowrite progbits
__al_vscan:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 104
    mov [rsp], rdi
    mov [rsp + 8], rcx
    mov rbx, rsi
    mov r12, rdx
    xor r14d, r14d                ; assignments
    xor r15d, r15d                ; completed conversion
    mov qword [rsp + 72], 1    ; format stride
    cmp rcx, 2
    jb .select_source
    mov qword [rsp + 72], 4
.select_source:
    cmp qword [rsp + 8], 1
    je .lock_stream
    cmp qword [rsp + 8], 3
    jne .scratch_lock
.lock_stream:
    call __al_stream_lock
    mov rdi, [rsp]
    cmp qword [rsp + 8], 3
    je .wide_orientation
    cmp dword [rdi + 128], 1
    je .wrong_orientation
    mov dword [rdi + 128], -1
    jmp .scratch_lock
.wide_orientation:
    mov esi, 1
    call __al_stream_orient
    test eax, eax
    jg .scratch_lock
.wrong_orientation:
    mov r14d, -1
    jmp .stream_unlock
.scratch_lock:
    lea rdi, [rel scan_lock]
    call __al_lock
    lea r13, [rel input]
    mov rax, [rsp]
    mov [r13], rax
    mov rax, [rsp + 8]
    mov [r13 + 8], rax
    mov qword [r13 + 16], 0       ; input units consumed
    mov qword [r13 + 24], -2      ; no peeked unit

.next:
    mov rdi, rbx
    mov rsi, [rsp + 72]
    call __al_fmt_unit
    test eax, eax
    jz .finish
    cmp eax, 37
    je .conversion
    mov edi, eax
    cmp qword [rsp + 72], 4
    je .wide_space
    call isspace
    jmp .format_space
.wide_space:
    call iswspace
.format_space:
    test eax, eax
    jz .literal
    add rbx, [rsp + 72]
    mov rdi, r13
    call __al_scan_space
    jmp .next
.literal:
    mov rdi, r13
    call __al_scan_peek
    test rax, rax
    js .input_failure
    mov [rsp + 88], eax
    mov rdi, rbx
    mov rsi, [rsp + 72]
    call __al_fmt_unit
    cmp eax, [rsp + 88]
    jne .finish
    add rbx, [rsp + 72]
    mov rdi, r13
    call __al_scan_take
    jmp .next

.conversion:
    add rbx, [rsp + 72]
    mov rdi, rbx
    mov rsi, [rsp + 72]
    call __al_fmt_unit
    cmp eax, 37
    jne .fields
    mov rdi, r13
    call __al_scan_space
    jmp .literal
.fields:
    mov qword [rsp + 16], -1      ; unlimited width
    mov qword [rsp + 24], 0       ; suppression
    mov qword [rsp + 32], 4       ; integer destination width
    mov qword [rsp + 80], 0
    cmp eax, 42
    jne .width
    add rbx, [rsp + 72]
    mov qword [rsp + 24], 1
.width:
    mov rdi, rbx
    mov rsi, [rsp + 72]
    call __al_fmt_decimal
    cmp rdx, rbx
    je .length
    test rax, rax
    jz .invalid
    mov [rsp + 16], rax
    mov rbx, rdx
.length:
    mov rdi, rbx
    mov rsi, [rsp + 72]
    call __al_fmt_unit
    cmp eax, 104
    je .short
    cmp eax, 108
    je .long
    cmp eax, 106
    je .one_long
    cmp eax, 122
    je .one_long
    cmp eax, 116
    je .one_long
    cmp eax, 76                  ; L selects extended precision
    je .extended
    jmp .specifier
.extended:
    add rbx, [rsp + 72]
    mov qword [rsp + 32], 16
    jmp .specifier
.short:
    add rbx, [rsp + 72]
    mov qword [rsp + 32], 2
    mov rdi, rbx
    mov rsi, [rsp + 72]
    call __al_fmt_unit
    cmp eax, 104
    jne .specifier
    add rbx, [rsp + 72]
    mov qword [rsp + 32], 1
    jmp .specifier
.long:
    add rbx, [rsp + 72]
    mov rdi, rbx
    mov rsi, [rsp + 72]
    call __al_fmt_unit
    cmp eax, 108
    jne .long_size
.one_long:
    add rbx, [rsp + 72]
.long_size:
    mov qword [rsp + 32], 8
.specifier:
    mov rdi, rbx
    mov rsi, [rsp + 72]
    call __al_fmt_unit
    test eax, eax
    jz .invalid
    cmp eax, 127
    ja .invalid
    add rbx, [rsp + 72]
    cmp eax, 110
    je .count
    cmp eax, 99
    je .characters
    cmp eax, 115
    je .string
    cmp eax, 91
    je .brackets
    cmp eax, 105
    je .auto
    cmp eax, 111
    je .octal
    cmp eax, 120
    je .hex
    cmp eax, 88
    je .hex
    cmp eax, 112
    je .pointer
    cmp eax, 100
    je .decimal
    cmp eax, 117
    jne .check_float
.decimal:
    mov qword [rsp + 40], 10
    jmp .number
.auto:
    mov qword [rsp + 40], 0
    jmp .number
.octal:
    mov qword [rsp + 40], 8
    jmp .number
.pointer:
    mov qword [rsp + 32], 8
.hex:
    mov qword [rsp + 40], 16
.number:
    cmp qword [rsp + 32], 16
    je .invalid
    mov rdi, r13
    call __al_scan_space
    mov rdi, r13
    mov rsi, [rsp + 16]
    mov rdx, [rsp + 40]
    call __al_scan_number
    test edx, edx
    jnz .number_failure
    cmp qword [rsp + 24], 0
    jne .completed
    mov [rsp + 64], rax
    mov rdi, r12
    call __al_va_next
    mov rdi, rax
    mov rsi, [rsp + 32]
    mov rdx, [rsp + 64]
    call __al_scan_store
    inc r14d
    jmp .completed
.number_failure:
    cmp edx, 2
    je .input_failure
    jmp .finish
.check_float:
    or eax, 32
    cmp eax, 97                  ; a/A
    je .float
    cmp eax, 101                 ; e/E
    je .float
    cmp eax, 102                 ; f/F
    je .float
    cmp eax, 103                 ; g/G
    jne .invalid
.float:
    mov qword [rsp + 40], 0      ; binary32
    mov rax, [rsp + 32]
    cmp rax, 4
    je .float_input
    cmp rax, 8
    je .double_input
    cmp rax, 16
    jne .invalid
    mov qword [rsp + 40], 2      ; extended
    jmp .float_input
.double_input:
    mov qword [rsp + 40], 1
.float_input:
    mov rdi, r13
    call __al_scan_space
    xor ecx, ecx
    cmp qword [rsp + 24], 0
    jne .scan_float
    mov rdi, r12
    call __al_va_next
    mov rcx, rax
.scan_float:
    mov rdi, r13
    mov rsi, [rsp + 16]
    mov rdx, [rsp + 40]
    call __al_scan_float
    cmp eax, 2
    je .input_failure
    test eax, eax
    jnz .finish
    cmp qword [rsp + 24], 0
    jne .completed
    inc r14d
    jmp .completed
.count:
    cmp qword [rsp + 32], 16
    je .invalid
    cmp qword [rsp + 24], 0
    jne .completed
    mov rdi, r12
    call __al_va_next
    mov rdi, rax
    mov rsi, [rsp + 32]
    mov rdx, [r13 + 16]
    call __al_scan_store
    jmp .completed

.characters:
    mov qword [rsp + 40], 0
    cmp qword [rsp + 16], -1
    jne .byte_field
    mov qword [rsp + 16], 1
    jmp .byte_field
.string:
    mov qword [rsp + 40], 1
    mov rdi, r13
    call __al_scan_space
    jmp .byte_field
.brackets:
    mov qword [rsp + 40], 2
    mov rdi, rbx
    cmp qword [rsp + 72], 4
    je .wide_brackets
    lea rsi, [rel scan_set]
    call __al_scan_set
    test rax, rax
    jz .invalid
    mov rbx, rax
    jmp .byte_field
.wide_brackets:
    mov [rsp + 80], rbx
    call __al_scan_wset
    test rax, rax
    jz .invalid
    mov rbx, rax
.byte_field:
    cmp qword [rsp + 72], 4
    je .wide_field
    cmp qword [rsp + 32], 4
    jne .invalid
    mov qword [rsp + 48], 0       ; destination or suppressed
    mov qword [rsp + 56], 0       ; optional temporary %c array
    cmp qword [rsp + 24], 0
    jne .scan_bytes
    mov rdi, r12
    call __al_va_next
    mov [rsp + 48], rax
    cmp qword [rsp + 40], 0
    jne .scan_bytes
    cmp qword [rsp + 16], 1
    je .scan_bytes
    mov rdi, [rsp + 16]
    call malloc
    test rax, rax
    jz .input_failure
    mov [rsp + 56], rax
.scan_bytes:
    mov rsi, [rsp + 56]
    test rsi, rsi
    jnz .byte_destination
    mov rsi, [rsp + 48]
.byte_destination:
    mov rdi, r13
    mov rdx, [rsp + 16]
    mov rcx, [rsp + 40]
    lea r8, [rel scan_set]
    call __al_scan_chars
    mov [rsp + 64], eax
    mov rsi, [rsp + 56]
    test rsi, rsi
    jz .byte_result
    test eax, eax
    jnz .release_temp
    mov rdi, [rsp + 48]
    mov rdx, [rsp + 16]
    call memcpy
.release_temp:
    mov rdi, [rsp + 56]
    call free
    jmp .byte_result
.wide_field:
    cmp qword [rsp + 32], 4
    je .wide_destination
    cmp qword [rsp + 32], 8
    jne .invalid
.wide_destination:
    mov qword [rsp + 48], 0     ; destination or suppressed
    mov qword [rsp + 56], 0     ; optional atomic c output
    cmp qword [rsp + 24], 0
    jne .scan_wide
    mov rdi, r12
    call __al_va_next
    mov [rsp + 48], rax
    cmp qword [rsp + 40], 0
    jne .scan_wide
    cmp qword [rsp + 16], 1
    je .scan_wide
    mov rdi, [rsp + 16]
    shl rdi, 2                  ; wchar_t or up to four encoded bytes
    call malloc
    test rax, rax
    jz .input_failure
    mov [rsp + 56], rax
.scan_wide:
    mov rsi, [rsp + 56]
    test rsi, rsi
    jnz .wide_output
    mov rsi, [rsp + 48]
.wide_output:
    mov rdi, r13
    mov rdx, [rsp + 16]
    mov rcx, [rsp + 40]
    mov r8, [rsp + 80]
    mov r9d, 1
    cmp qword [rsp + 32], 8
    jne .wide_units
    mov r9d, 4
.wide_units:
    call __al_scan_wchars
    mov [rsp + 64], eax
    mov rsi, [rsp + 56]
    test rsi, rsi
    jz .byte_result
    test eax, eax
    jnz .wide_release
    mov rdi, [rsp + 48]
    call memcpy
.wide_release:
    mov rdi, [rsp + 56]
    call free
.byte_result:
    mov eax, [rsp + 64]
    cmp eax, 2
    je .input_failure
    test eax, eax
    jnz .finish
    cmp qword [rsp + 24], 0
    jne .completed
    inc r14d
.completed:
    mov r15d, 1
    jmp .next

.invalid:
    mov edi, 22
    call __al_stdio_errno
.input_failure:
    test r15d, r15d
    jnz .finish
    mov r14d, -1
.finish:
    cmp qword [r13 + 8], 1
    je .preserve_peek
    cmp qword [r13 + 8], 3
    jne .unlock
.preserve_peek:
    mov rax, [r13 + 24]
    test rax, rax
    js .unlock
    mov rdi, [r13]
    cmp qword [r13 + 8], 3
    je .wide_peek
    mov [rdi + 72], rax
    jmp .clear_eof
.wide_peek:
    cmp dword [r13 + 52], 0
    je .wide_physical_peek
    mov [rdi + 144], eax        ; restore the caller’s synthetic pushback
    jmp .clear_eof
.wide_physical_peek:
    mov [rdi + 148], eax
    mov eax, [r13 + 48]
    mov [rdi + 160], eax
    mov rax, [r13 + 56]
    mov [rdi + 168], rax
.clear_eof:
    and qword [rdi + 8], -17
.unlock:
    lea rdi, [rel scan_lock]
    call __al_unlock
    cmp qword [rsp + 8], 1
    je .stream_unlock
    cmp qword [rsp + 8], 3
    jne .result
.stream_unlock:
    mov rdi, [rsp]
    call __al_stream_unlock
.result:
    mov eax, r14d
    add rsp, 104
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .bss.__al_vscan alloc noexec write nobits align=8
input:
    resq 8
scan_set:
    resb 256

scan_lock:
    resd 1

section .note.GNU-stack noalloc noexec nowrite progbits
