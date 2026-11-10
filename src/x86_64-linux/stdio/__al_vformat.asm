; Original byte and wide format interpreter.
; rdi = sink, rsi = size for string output, rdx = format, rcx = va_list.
; Sink kind r8 is 0 byte buffer, 1 byte stream, 2 allocated byte buffer,
; 3 wide buffer, or 4 wide stream.
; The allocated sink receives a char ** in rdi.
bits 64
default rel

global __al_vformat:function
extern __al_fork_scratch_locks:data
extern __al_stream_lock:function
extern __al_stream_unlock:function
extern __al_lock:function
extern __al_unlock:function
extern __al_va_next:function
extern __al_fmt_decimal:function
extern __al_fmt_emit:function
extern __al_fmt_integer:function
extern __al_fmt_float:function
extern __al_va_double:function
extern __al_va_extended:function
extern __al_fmt_text:function
extern __al_fmt_unit:function
extern __al_fmt_wemit:function
extern __al_fmt_wtext:function
extern __al_fmt_nwide:function
extern __al_stream_orient:function
extern __al_stdio_errno:function
extern strlen:function
extern malloc:function
extern free:function

section .text.__al_vformat alloc exec nowrite progbits
__al_vformat:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 40
    mov [rsp], rdi
    mov [rsp + 8], rsi
    mov [rsp + 16], r8
    mov rbx, rdx                  ; format cursor
    mov r12, rcx                  ; variadic cursor
    mov qword [rsp + 24], 1    ; format stride
    cmp r8, 3
    jb .select_sink
    mov qword [rsp + 24], 4
    cmp r8, 3
    jne .select_sink
    test rsi, rsi
    jnz .select_sink
    mov r14d, -1               ; no room even for the terminal wide null
    jmp .result
.select_sink:
    cmp qword [rsp + 16], 1
    je .lock_stream
    cmp qword [rsp + 16], 4
    jne .scratch_lock
.lock_stream:
    call __al_stream_lock
    mov rdi, [rsp]
    cmp qword [rsp + 16], 4
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
    lea rdi, [rel __al_fork_scratch_locks + 4]
    call __al_lock
    lea r13, [rel output]
    lea r15, [rel fields]
    mov rax, [rsp]
    mov [r13], rax
    mov rax, [rsp + 16]
    mov [r13 + 24], rax           ; sink kind
    mov qword [r13 + 16], 0       ; full output count
    mov rax, [rsp + 8]
    mov [r13 + 40], rax           ; original destination capacity
    test rax, rax
    jz .capacity
    dec rax
.capacity:
    mov [r13 + 8], rax
    cmp qword [r13 + 24], 2
    jne .next
    mov rax, [r13]
    mov [r13 + 48], rax           ; char **result for the allocated sink
    mov qword [r13], 0

.next:
    cmp qword [rsp + 24], 4
    je .wide_next
    cmp byte [rbx], 0
    je .success
    cmp byte [rbx], 37
    je .conversion
    mov rsi, rbx
    xor edx, edx
.literal:
    inc rbx
    inc rdx
    cmp byte [rbx], 0
    je .emit
    cmp byte [rbx], 37
    jne .literal
.emit:
    mov rdi, r13
    xor ecx, ecx
.call_emit:
    call __al_fmt_emit
    test eax, eax
    jz .next
    jmp .failure
.wide_next:
    cmp dword [rbx], 0
    je .success
    cmp dword [rbx], 37
    je .conversion
    mov rsi, rbx
    xor edx, edx
.wide_literal:
    add rbx, 4
    inc rdx
    cmp dword [rbx], 0
    je .wide_literal_emit
    cmp dword [rbx], 37
    jne .wide_literal
.wide_literal_emit:
    mov rdi, r13
    xor ecx, ecx
    mov r8d, 4
    call __al_fmt_wemit
    test eax, eax
    jz .next
    jmp .failure

.conversion:
    add rbx, [rsp + 24]
    mov rdi, rbx
    mov rsi, [rsp + 24]
    call __al_fmt_unit
    cmp eax, 37
    jne .start_fields
    add rbx, [rsp + 24]
    mov rdi, r13
    xor esi, esi
    mov edx, 1
    mov ecx, 37
    jmp .call_emit
.start_fields:
    mov qword [r15], 0            ; flags
    mov qword [r15 + 16], -1      ; absent precision
    mov qword [r15 + 24], 4       ; default promoted integer size
.flags:
    mov rdi, rbx
    mov rsi, [rsp + 24]
    call __al_fmt_unit
    cmp eax, 45
    je .left
    cmp eax, 43
    je .plus
    cmp eax, 32
    je .space
    cmp eax, 35
    je .alternate
    cmp eax, 48
    jne .width
    or qword [r15], 16
    jmp .flag_next
.left:
    or qword [r15], 1
    jmp .flag_next
.plus:
    or qword [r15], 2
    jmp .flag_next
.space:
    or qword [r15], 4
    jmp .flag_next
.alternate:
    or qword [r15], 8
.flag_next:
    add rbx, [rsp + 24]
    jmp .flags

.width:
    cmp eax, 42
    jne .literal_width
    add rbx, [rsp + 24]
    mov rdi, r12
    call __al_va_next
    movsxd rax, eax
    test rax, rax
    jns .width_ready
    or qword [r15], 1
    neg rax
    jmp .width_ready
.literal_width:
    mov rdi, rbx
    mov rsi, [rsp + 24]
    call __al_fmt_decimal
    mov rbx, rdx
.width_ready:
    cmp rax, 2147483647
    ja .overflow
    mov [r15 + 8], rax
    mov rdi, rbx
    mov rsi, [rsp + 24]
    call __al_fmt_unit
    cmp eax, 46
    jne .length
    add rbx, [rsp + 24]
    mov rdi, rbx
    mov rsi, [rsp + 24]
    call __al_fmt_unit
    cmp eax, 42
    jne .literal_precision
    add rbx, [rsp + 24]
    mov rdi, r12
    call __al_va_next
    movsxd rax, eax
    test rax, rax
    js .length
    jmp .save_precision
.literal_precision:
    mov rdi, rbx
    mov rsi, [rsp + 24]
    call __al_fmt_decimal
    mov rbx, rdx
.save_precision:
    mov [r15 + 16], rax
.length:
    mov rdi, rbx
    mov rsi, [rsp + 24]
    call __al_fmt_unit
    cmp eax, 104                  ; h or hh
    je .short
    cmp eax, 108                  ; l or ll
    je .long
    cmp eax, 106                  ; j
    je .one_long
    cmp eax, 122                  ; z
    je .one_long
    cmp eax, 116                  ; t
    je .one_long
    cmp eax, 76                   ; L
    je .extended
    jmp .specifier
.extended:
    add rbx, [rsp + 24]
    mov qword [r15 + 24], 16
    jmp .specifier
.short:
    add rbx, [rsp + 24]
    mov qword [r15 + 24], 2
    mov rdi, rbx
    mov rsi, [rsp + 24]
    call __al_fmt_unit
    cmp eax, 104
    jne .specifier
    add rbx, [rsp + 24]
    mov qword [r15 + 24], 1
    jmp .specifier
.long:
    add rbx, [rsp + 24]
    mov rdi, rbx
    mov rsi, [rsp + 24]
    call __al_fmt_unit
    cmp eax, 108
    jne .long_size
.one_long:
    add rbx, [rsp + 24]
.long_size:
    mov qword [r15 + 24], 8
.specifier:
    mov rdi, rbx
    mov rsi, [rsp + 24]
    call __al_fmt_unit
    mov [r15 + 32], rax
    test eax, eax
    jz .invalid
    cmp eax, 127
    ja .invalid
    add rbx, [rsp + 24]
    cmp eax, 99
    je .character
    cmp eax, 115
    je .string
    cmp eax, 110
    je .store_count
    cmp eax, 100
    je .integer
    cmp eax, 105
    je .integer
    cmp eax, 111
    je .integer
    cmp eax, 117
    je .integer
    cmp eax, 120
    je .integer
    cmp eax, 88
    je .integer
    cmp eax, 112
    jne .check_float
.integer:
    cmp qword [r15 + 24], 16
    je .invalid
    mov rdi, r12
    call __al_va_next
    mov rdi, r13
    mov rsi, r15
    mov rdx, rax
    call __al_fmt_integer
    test eax, eax
    jz .next
    jmp .failure
.check_float:
    or eax, 32
    cmp eax, 97                   ; a/A
    je .float
    cmp eax, 101                  ; e/E
    je .float
    cmp eax, 102                  ; f/F
    je .float
    cmp eax, 103                  ; g/G
    jne .invalid
.float:
    mov rdi, r12
    cmp qword [r15 + 24], 16
    je .take_extended
    cmp qword [r15 + 24], 4
    je .take_double
    cmp qword [r15 + 24], 8
    jne .invalid
.take_double:
    call __al_va_double
    xor ecx, ecx
    jmp .render_float
.take_extended:
    call __al_va_extended
    mov ecx, edx
.render_float:
    mov rdi, r13
    mov rsi, r15
    mov rdx, rax
    call __al_fmt_float
    test eax, eax
    jz .next
    jmp .failure

.character:
    cmp qword [rsp + 16], 3
    jae .wide_text
    cmp qword [r15 + 24], 8
    je .narrow_wide_text
    cmp qword [r15 + 24], 4
    jne .invalid
    mov rdi, r12
    call __al_va_next
    mov [r13 + 32], al
    lea rdx, [r13 + 32]
    mov ecx, 1
    jmp .emit_text
.string:
    cmp qword [rsp + 16], 3
    jae .wide_text
    cmp qword [r15 + 24], 8
    je .narrow_wide_text
    cmp qword [r15 + 24], 4
    jne .invalid
    mov rdi, r12
    call __al_va_next
    mov r14, rax
    test r14, r14
    jnz .string_length
    lea r14, [rel null_text]
.string_length:
    mov r8, [r15 + 16]
    test r8, r8
    js .unbounded
    xor ecx, ecx
.bounded:
    cmp rcx, r8
    jae .string_ready
    cmp byte [r14 + rcx], 0
    je .string_ready
    inc rcx
    jmp .bounded
.unbounded:
    mov rdi, r14
    call strlen
    mov rcx, rax
.string_ready:
    mov rdx, r14
.emit_text:
    mov rdi, r13
    mov rsi, r15
    call __al_fmt_text
    test eax, eax
    jz .next
    jmp .failure
.narrow_wide_text:
    mov rdi, r12
    call __al_va_next
    mov rdi, r13
    mov rsi, r15
    mov rdx, rax
    call __al_fmt_nwide
    test eax, eax
    jz .next
    jmp .failure
.wide_text:
    mov rdi, r12
    call __al_va_next
    mov rdi, r13
    mov rsi, r15
    mov rdx, rax
    call __al_fmt_wtext
    test eax, eax
    jz .next
    jmp .failure
.store_count:
    cmp qword [r15 + 24], 16
    je .invalid
    mov rdi, r12
    call __al_va_next
    mov rcx, [r13 + 16]
    cmp qword [r15 + 24], 8
    je .count_long
    cmp qword [r15 + 24], 4
    je .count_int
    cmp qword [r15 + 24], 2
    je .count_short
    mov [rax], cl
    jmp .next
.count_short:
    mov [rax], cx
    jmp .next
.count_int:
    mov [rax], ecx
    jmp .next
.count_long:
    mov [rax], rcx
    jmp .next

.invalid:
    mov edi, 22
    jmp .errno
.overflow:
    mov edi, 75
.errno:
    call __al_stdio_errno
.failure:
    mov r14d, -1
    jmp .terminate
.success:
    mov r14d, [r13 + 16]
.terminate:
    cmp qword [r13 + 24], 3
    je .wide_terminate
    cmp qword [r13 + 24], 2
    je .dynamic_finish
    cmp qword [r13 + 24], 0
    jne .unlock
    cmp qword [r13 + 40], 0
    je .unlock
    mov rax, [r13 + 16]
    cmp rax, [r13 + 8]
    jbe .nul
    mov rax, [r13 + 8]
.nul:
    mov rcx, [r13]
    mov byte [rcx + rax], 0
    jmp .unlock
.wide_terminate:
    mov rax, [r13 + 16]
    mov rcx, [r13]
    mov dword [rcx + rax * 4], 0
    jmp .unlock
.dynamic_finish:
    mov rax, [r13]
    test r14d, r14d
    js .dynamic_failure
    test rax, rax
    jnz .dynamic_nul
    mov edi, 1                    ; empty output still owns a string
    call malloc
    test rax, rax
    jnz .dynamic_nul
    mov r14d, -1
    jmp .dynamic_publish
.dynamic_nul:
    mov byte [rax + r14], 0
    jmp .dynamic_publish
.dynamic_failure:
    mov rdi, rax
    call free
    xor eax, eax
.dynamic_publish:
    mov rcx, [r13 + 48]
    mov [rcx], rax
.unlock:
    lea rdi, [rel __al_fork_scratch_locks + 4]
    call __al_unlock
    cmp qword [rsp + 16], 1
    je .stream_unlock
    cmp qword [rsp + 16], 4
    jne .result
.stream_unlock:
    mov rdi, [rsp]
    call __al_stream_unlock
.result:
    mov eax, r14d
    add rsp, 40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.__al_vformat alloc noexec nowrite progbits
null_text:
    db "(null)", 0

section .bss.__al_vformat alloc noexec write nobits align=8
output:
    resb 128
fields:
    resq 5


section .note.GNU-stack noalloc noexec nowrite progbits
