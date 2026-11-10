; BEGIN OPEN ASSEMBLY GENERATED SPEC
; function: __atomic_is_lock_free
; header: compiler_rt.h
; prototype: _Bool __atomic_is_lock_free(size_t size, const volatile void *object)
; standard: Runtime ABI __atomic_is_lock_free
; deps: -
; errno: -
; mt_safe: true
; as_safe: true
; oracles: reference:compiler-atomic-abi, diff:libatomic
; provenance: original
; narrow_args: -
; variadic: false
; semantics: Report naturally aligned sizes 1, 2, 4, and 8 as lock-free without dereferencing object.
; semantics: Preserve errno.
; END OPEN ASSEMBLY GENERATED SPEC

bits 64
default rel

global __atomic_is_lock_free:function

section .text.__atomic_is_lock_free alloc exec nowrite progbits
__atomic_is_lock_free:
    xor eax, eax
    test rdi, rdi
    jz .done
    cmp rdi, 8
    ja .done
    lea rdx, [rdi - 1]
    test rdx, rdi
    jnz .done
    test rdx, rsi
    jnz .done
    mov eax, 1
.done:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
