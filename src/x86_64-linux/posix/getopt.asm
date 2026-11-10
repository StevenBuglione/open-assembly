; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: getopt
; header: unistd.h
; prototype: int getopt(int argc, char *const argv[], const char *optstring)
; standard: POSIX.1-2024 XSH getopt
; deps: __errno_location, fprintf
; errno: -
; mt_safe: false
; as_safe: false
; oracles: diff:glibc, diff:musl, reference:linux-busybox-abi
; provenance: original
; narrow_args: edi:s32
; variadic: false
; semantics: Process POSIX grouped short options without permuting arguments. An optional leading plus selects the same ordering.
; semantics: Stop before the first operand or consume an explicit double-hyphen terminator.
; semantics: Read required option arguments from the remainder of a group or the next argument.
; semantics: For unknown or incomplete options update optopt, return question mark or a leading-colon missing-argument result, and follow opterr and colon diagnostics policy.
; semantics: Maintain optind and optarg. The Linux compatibility reset optind equal to zero starts a new scan at one.
; semantics: Each process has one getopt state. Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global getopt:function
global optarg:data
global opterr:data
global optind:data
global optopt:data
extern __errno_location:function
extern fprintf:function
extern stderr:data

section .text.getopt alloc exec nowrite progbits
getopt:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 24
    movsxd r13, edi               ; argc
    mov rbx, rsi                  ; argv
    mov r12, rdx                  ; optstring
    cmp byte [r12], 43            ; accept explicit POSIX ordering
    jne .prepare
    inc r12
.prepare:
    mov qword [rel optarg], 0
    movsxd rax, dword [rel optind]
    test rax, rax
    jnz .check_scan
    mov eax, 1
    mov dword [rel optind], 1
    jmp .new_scan
.check_scan:
    cmp rbx, [rel scan_argv]
    jne .new_scan
    cmp eax, [rel scan_index]
    je .bounds
.new_scan:
    mov [rel scan_argv], rbx
    mov qword [rel next_offset], 0
.bounds:
    cmp rax, 1
    jl .stop
    cmp rax, r13
    jge .stop
    mov r15, [rbx + rax * 8]
    test r15, r15
    jz .stop
    mov rdx, [rel next_offset]
    test rdx, rdx
    jnz .select
    cmp byte [r15], 45
    jne .stop
    cmp byte [r15 + 1], 0
    je .stop
    cmp byte [r15 + 1], 45
    jne .start_group
    cmp byte [r15 + 2], 0
    jne .start_group
    inc eax                      ; consume the explicit terminator
    mov [rel optind], eax
    jmp .stop
.start_group:
    mov edx, 1
.select:
    movzx r14d, byte [r15 + rdx]
    inc rdx
    cmp byte [r15 + rdx], 0
    je .end_group
    mov [rel next_offset], rdx
    jmp .remember_index
.end_group:
    inc eax
    mov [rel optind], eax
    mov qword [rel next_offset], 0
.remember_index:
    mov [rel scan_index], eax
    cmp r14b, 58                  ; colon is reserved by optstring grammar
    je .unknown
    mov rcx, r12
    cmp byte [rcx], 58
    jne .find_option
    inc rcx
.find_option:
    movzx esi, byte [rcx]
    test esi, esi
    jz .unknown
    cmp esi, r14d
    je .found
    inc rcx
    jmp .find_option
.found:
    cmp byte [rcx + 1], 58
    jne .option
    cmp byte [r15 + rdx], 0
    je .next_argument
    lea rcx, [r15 + rdx]
    jmp .argument
.next_argument:
    cmp rax, r13
    jge .missing
    mov rcx, [rbx + rax * 8]
    test rcx, rcx
    jz .missing
.argument:
    inc eax
    mov [rel optarg], rcx
    mov [rel optind], eax
    mov [rel scan_index], eax
    mov qword [rel next_offset], 0
.option:
    mov eax, r14d
    jmp .done
.unknown:
    mov [rel optopt], r14d
    cmp byte [r12], 58
    je .question
    lea r15, [rel invalid_option]
    jmp .diagnose
.missing:
    mov [rel optopt], r14d
    cmp byte [r12], 58
    jne .diagnose_missing
    mov eax, 58
    jmp .done
.diagnose_missing:
    lea r15, [rel missing_argument]
.diagnose:
    cmp dword [rel opterr], 0
    je .question
    call __errno_location
    mov [rsp + 8], rax
    mov edx, [rax]
    mov [rsp], edx
    mov rdx, [rbx]
    test rdx, rdx
    jnz .print
    lea rdx, [rel default_name]
.print:
    mov rdi, [rel stderr]
    mov rsi, r15
    mov ecx, r14d
    xor eax, eax
    call fprintf
    mov rax, [rsp + 8]
    mov edx, [rsp]
    mov [rax], edx
.question:
    mov eax, 63
    jmp .done
.stop:
    mov [rel scan_index], eax
    mov qword [rel next_offset], 0
    mov eax, -1
.done:
    add rsp, 24
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .rodata.getopt alloc noexec nowrite progbits
invalid_option:
    db "%s: invalid option -- '%c'", 10, 0
missing_argument:
    db "%s: option requires an argument -- '%c'", 10, 0
default_name:
    db "getopt", 0

section .data.getopt alloc noexec write progbits align=4
optind:
    dd 1
opterr:
    dd 1

section .bss.getopt alloc noexec write nobits align=8
optarg:
    resq 1
scan_argv:
    resq 1
next_offset:
    resq 1
optopt:
    resd 1
scan_index:
    resd 1

section .note.GNU-stack noalloc noexec nowrite progbits
