"""Conservative verifier for the supported NASM x86-64 subset."""

from __future__ import annotations

import argparse
from collections import deque
from dataclasses import dataclass, replace
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
SYMBOL = r"[A-Za-z_][A-Za-z0-9_]*"
LABEL = rf"(?:{SYMBOL}|\.[A-Za-z_][A-Za-z0-9_]*)"
INTEGER = r"[+-]?(?:0[xX][0-9A-Fa-f]+|0[bB][01]+|[0-9]+)"
CALLEE = frozenset(("rbx", "rbp", "r12", "r13", "r14", "r15"))
ARGUMENTS = ("rdi", "rsi", "rdx", "rcx", "r8", "r9")
REGISTERS = {}
for base, dword, word, low, high in (
    ("rax", "eax", "ax", "al", "ah"), ("rbx", "ebx", "bx", "bl", "bh"),
    ("rcx", "ecx", "cx", "cl", "ch"), ("rdx", "edx", "dx", "dl", "dh"),
    ("rsp", "esp", "sp", "spl", ""), ("rbp", "ebp", "bp", "bpl", ""),
    ("rsi", "esi", "si", "sil", ""), ("rdi", "edi", "di", "dil", ""),
):
    REGISTERS.update({name: (base, width) for name, width in
                      zip((base, dword, word, low, high), (64, 32, 16, 8, 8)) if name})
for n in range(8, 16):
    base = f"r{n}"
    REGISTERS.update({base + suffix: (base, width) for suffix, width in
                      (("", 64), ("d", 32), ("w", 16), ("b", 8))})

JCC = frozenset(("ja", "jae", "jb", "jbe", "jc", "je", "jg", "jge", "jl",
                 "jle", "jna", "jnae", "jnb", "jnbe", "jnc", "jne", "jng",
                 "jnge", "jnl", "jnle", "jno", "jnp", "jns", "jnz", "jo",
                 "jp", "jpe", "jpo", "js", "jz"))
MOVES = frozenset(("mov", "movzx", "movsx", "movsxd", "lea"))
ARITH = frozenset(("add", "sub", "adc", "sbb", "and", "or", "xor", "shl",
                   "sal", "shr", "sar", "rol", "ror", "imul"))
UNARY = frozenset(("inc", "dec", "not", "neg", "bswap"))
SSE_MOVE = frozenset(("movd", "movq", "movdqa", "movdqu", "movapd", "movaps",
                      "movupd", "movups", "movsd", "movss", "pmovmskb"))
SSE_ALU = frozenset(("pxor", "pand", "pandn", "por", "pcmpeqb", "pcmpeqw",
                     "pcmpeqd", "paddb", "paddw", "paddd", "paddq", "psubb",
                     "psubw", "psubd", "psubq", "pslldq", "psrldq", "divsd", "mulsd"))
AFTER_SSE2 = frozenset(("addsubpd", "addsubps", "haddpd", "haddps", "hsubpd",
                        "hsubps", "lddqu", "movddup", "movshdup", "movsldup",
                        "palignr", "pabsb", "pabsd", "pabsw", "pshufb",
                        "pblendw", "pblendvb", "blendps", "blendpd", "ptest",
                        "popcnt", "lzcnt", "tzcnt", "crc32", "pclmulqdq", "xgetbv",
                        "andn", "bextr", "blsi", "blsmsk", "blsr", "bzhi", "mulx",
                        "pdep", "pext", "rorx", "sarx", "shlx", "shrx", "rdrand",
                        "rdseed", "movbe", "endbr64", "endbr32"))
DATA = frozenset(("db", "dw", "dd", "dq", "dt", "do", "dy", "dz", "resb",
                  "resw", "resd", "resq", "rest", "reso", "resy", "resz",
                  "incbin", "times", "align", "alignb"))
SIZE = {"byte": 1, "word": 2, "dword": 4, "qword": 8, "tword": 10, "oword": 16}
RUNTIME = ("src", "x86_64-linux")
PRIVATE_FUNCTIONS = {
    "math/__al_big_muladd", "math/__al_big_left", "math/__al_big_right1",
    "math/__al_big_cmp", "math/__al_big_sub", "math/__al_big_bits", "math/__al_big_copy",
    "math/__al_float_lex", "math/__al_float_round", "math/__al_strtof_core",
    "math/__al_big_bad", "math/__al_float_keyword",
    "stdio/__al_scan_float", "stdio/__al_va_double", "stdio/__al_va_extended",
    "math/__al_big_divsmall", "math/__al_float_decimal", "math/__al_round_decimal",
    "stdio/__al_fmt_float", "stdio/__al_fmt_dec_body", "stdio/__al_fmt_hex_body",
    "stdio/__al_fmt_fp_output", "stdio/__al_fmt_exponent",
    "rt/__al_stdio_init", "stdio/__al_stdio_isatty", "stdio/__al_stdio_io",
    "stdio/__al_stdio_seek", "stdio/__al_stdio_open", "stdio/__al_stdio_errno",
    "stdio/__al_stream_flush", "stdio/__al_stream_read", "stdio/__al_stream_write",
    "stdio/__al_stream_close", "stdio/__al_stream_init",
    "stdio/__al_va_next", "stdio/__al_vformat", "stdio/__al_fmt_emit",
    "stdio/__al_fmt_decimal", "stdio/__al_fmt_text", "stdio/__al_fmt_integer",
    "stdio/__al_vscan", "stdio/__al_scan_peek", "stdio/__al_scan_take",
    "stdio/__al_scan_space", "stdio/__al_scan_set", "stdio/__al_scan_chars",
    "stdio/__al_scan_number", "stdio/__al_scan_store",
    "rt/__al_map_anon", "rt/__al_unmap_anon", "rt/__al_env_init",
    "stdlib/__al_heap", "stdlib/__al_heap_alloc", "stdlib/__al_heap_free",
    "stdlib/__al_heap_inspect", "stdlib/__al_heap_tag", "stdlib/__al_heap_bad",
    "stdlib/__al_env_change", "stdlib/__al_env_match", "stdlib/__al_env_name",
    "stdlib/__al_env_collect",
    "internal/__al_syscall", "internal/__al_syscall_result", "internal/__al_rt_sigreturn",
    "internal/__al_fcntl", "internal/__al_stat_query", "internal/__al_sigset_publish",
    "internal/__al_lock", "internal/__al_unlock", "rt/_start", "rt/__al_tls_init",
    "rt/__al_panic", "rt/__al_abort", "rt/__al_diagnostic", "stdlib/__al_strtox",
}
PRIVATE_NORETURN = {"_start", "__al_rt_sigreturn", "__al_panic", "__al_abort", "__al_heap_bad", "__al_big_bad"}
COMPARATOR_ARGUMENTS = {"bsearch": "r8", "qsort": "rcx"}


@dataclass(frozen=True)
class KernelStackRecord:
    extent: int
    setup: tuple[tuple[str, tuple[str, ...]], ...]
    finishes: tuple[tuple[tuple[str, tuple[str, ...]], ...], ...] = ((),)


SIGACTION_STACK_RECORDS = {
    ("rcx", "rsp + 40"): KernelStackRecord(32, (("mov", ("edi", "13")),),
                                          ((), (("lea", ("rdx", "[rsp + 8]")),))),
    ("rdx", "rsp + 8"): KernelStackRecord(32, (("mov", ("edi", "13")), ("lea", ("rcx", "[rsp + 40]")))),
}
KERNEL_STACK_RECORDS = {
    "internal/__al_stat_query": {
        ("rdx", "rsp + 8"): KernelStackRecord(144, (("mov", ("edi", "5")),)),
        ("rcx", "rsp + 8"): KernelStackRecord(144, (("mov", ("edi", "262")),)),
    },
    "posix/isatty": {
        ("rcx", "rsp + 8"): KernelStackRecord(64, (("mov", ("edi", "16")), ("mov", ("edx", "0x5401")))),
    },
    "signal/sigaction": SIGACTION_STACK_RECORDS,
    "signal/signal": SIGACTION_STACK_RECORDS,
}
PRIVATE_DATA = {
    "stdin": "rt/__al_stdio_init", "stdout": "rt/__al_stdio_init", "stderr": "rt/__al_stdio_init",
    "__al_stdio_lock": "rt/__al_stdio_init", "__al_streams": "rt/__al_stdio_init",
    "__al_heap_seed": "stdlib/__al_heap",
    "environ": "rt/__al_env_init",
    "optarg": "posix/getopt", "opterr": "posix/getopt", "optind": "posix/getopt", "optopt": "posix/getopt",
    "__al_env_lock": "rt/__al_env_init",
    "__al_env_owned": "stdlib/__al_env_change",
    "__al_initial_envp": "rt/_start",
    "__al_auxv": "rt/_start",
    "__al_atexit_state": "stdlib/atexit",
}
JUMP_SAVED_REGISTERS = ("rbx", "rbp", "r12", "r13", "r14", "r15")
JUMP_REGISTER_SLOTS = ("[rdi]", *(f"[rdi + {offset}]" for offset in range(8, 48, 8)))
JUMP_SAVE = tuple(("mov", (slot, reg)) for slot, reg in zip(JUMP_REGISTER_SLOTS, JUMP_SAVED_REGISTERS)) + (
    ("lea", ("rax", "[rsp + 8]")), ("mov", ("[rdi + 48]", "rax")),
    ("mov", ("rax", "[rsp]")), ("mov", ("[rdi + 56]", "rax")),
)
JUMP_RESTORE = (
    ("movsxd", ("rax", "esi")), ("test", ("eax", "eax")), ("jnz", (".restore",)),
    ("mov", ("eax", "1")), ("mov", ("r11", "[rdi + 56]")), ("mov", ("r10", "[rdi + 48]")),
) + tuple(("mov", (reg, slot)) for slot, reg in zip(JUMP_REGISTER_SLOTS, JUMP_SAVED_REGISTERS)) + (
    ("mov", ("rsp", "r10")), ("jmp", ("r11",)),
)
DATA_SECTIONS = {
    ".rodata": {"progbits", "alloc", "noexec", "nowrite"},
    ".data": {"progbits", "alloc", "noexec", "write"},
    ".bss": {"nobits", "alloc", "noexec", "write"},
}
VARARGS_WRAPPERS = {
    f"stdio/{name}": (target, fixed, register)
    for name, target, fixed, register in (
        ("printf", "vprintf", 1, "rsi"), ("fprintf", "vfprintf", 2, "rdx"),
        ("sprintf", "vsprintf", 2, "rdx"), ("snprintf", "vsnprintf", 3, "rcx"),
        ("scanf", "vscanf", 1, "rsi"), ("fscanf", "vfscanf", 2, "rdx"),
        ("sscanf", "vsscanf", 2, "rdx"),
    )
}


class Violation(Exception):
    def __init__(self, line: int, rule: str, message: str):
        self.line = line
        self.rule = rule
        self.message = message


def reject(line, rule, message):
    raise Violation(line, rule, message)


def integer(value):
    if not re.fullmatch(INTEGER, value):
        return None
    return int(value, 0) if value.lstrip("+-").lower().startswith(("0x", "0b")) else int(value)


@dataclass(frozen=True)
class Operand:
    value: str
    kind: str
    base: str = ""
    width: int = 0
    address: tuple[str, ...] = ()
    size: int = 0
    segment: str = ""


def operand(value, line):
    reg = value.lower()
    if reg in REGISTERS:
        base, width = REGISTERS[reg]
        return Operand(reg, "gpr", base, width)
    if re.fullmatch(r"xmm(?:[0-9]|1[0-5])", reg):
        return Operand(reg, "xmm", reg, 128)
    if re.fullmatch(r"st[0-7]", reg):
        return Operand(reg, "x87", reg, 80)
    mem = re.fullmatch(r"(?:(byte|word|dword|qword|tword|oword)\s+)?\[([^\[\]]+)\]", value, re.I)
    if mem:
        expression = re.sub(r"^rel\s+", "", mem[2], flags=re.I)
        if expression.lower().startswith("fs:"):
            offset = integer(expression[3:].strip())
            if offset != 0:
                reject(line, "TLS_ADDRESS", "only the TCB self pointer at fs:0 is modeled")
            return Operand("0", "mem", size=SIZE.get((mem[1] or "").lower(), 0), segment="fs")
        atom = r"(?:[a-zA-Z_][a-zA-Z0-9_]*|0[xX][0-9a-fA-F]+|0[bB][01]+|[0-9]+)"
        if not re.fullmatch(rf"\s*[+-]?\s*{atom}(?:\s*[-+*]\s*{atom})*\s*", expression):
            reject(line, "INSTRUCTION", f"unsupported address expression {mem[2]!r}")
        registers = tuple(REGISTERS[token.lower()][0] for token in
                          re.findall(r"[A-Za-z_][A-Za-z0-9_]*", expression)
                          if token.lower() in REGISTERS)
        return Operand(expression.strip(), "mem", address=registers,
                       size=SIZE.get((mem[1] or "").lower(), 0))
    if integer(value) is not None:
        return Operand(value, "imm")
    if re.fullmatch(LABEL, value):
        return Operand(value, "symbol")
    reject(line, "INSTRUCTION", f"unsupported operand {value!r}")


@dataclass(frozen=True)
class Instruction:
    line: int
    opcode: str
    operands: tuple[str, ...]
    scope: str


@dataclass(frozen=True)
class State:
    rsp: int = 0
    rbp_frame: int | None = None
    dirty: frozenset[str] = frozenset()
    saved: frozenset[tuple[int, str]] = frozenset()
    slots: frozenset[tuple[int, str]] = frozenset()
    df: bool = False
    x87_depth: int = 0
    control_dirty: frozenset[str] = frozenset()
    pending_args: frozenset[str] = frozenset()
    variadic_al_ready: bool = False
    r10_ready: bool = False
    syscall_clobbers: frozenset[str] = frozenset()
    process_entry: bool = False
    caller_stack_arg: bool = False
    tls_self: bool = False
    callback_table_registers: frozenset[str] = frozenset()
    callback_registers: frozenset[str] = frozenset()
    context_save: bool = False


@dataclass
class Program:
    instructions: list[Instruction]
    entries: dict[str, int]
    labels: dict[str, int]
    externs: set[str]
    narrow: dict[str, tuple[str, str]]
    variadic: set[str]
    data_symbols: set[str]
    external_data: set[str]
    external_signatures: set[str] | None = None
    noreturn: frozenset[str] = frozenset()
    process_entry: bool = False
    signal_restorer: bool = False
    caller_stack_arg: bool = False
    tls_self: bool = False
    callback_dispatch: bool = False
    callback_table: bool = False
    comparator_argument: str | None = None
    varargs_frame: bool = False
    fenv_access: bool = False
    fenv_controls: bool = False
    context_save: bool = False
    kernel_stack_records: dict[tuple[str, str], KernelStackRecord] | None = None


def parse(source, narrow, variadic, allow_seed_metadata):
    instructions = []
    labels = {}
    exports = {}
    externs = set()
    data_exports = {}
    data_externs = set()
    data_labels = set()
    sections = set()
    note = False
    section = None
    scope = ""
    section_start = True
    for line, raw in enumerate(source.splitlines(), 1):
        body, _, comment = raw.partition(";")
        comment = comment.strip()
        if comment.startswith(("lint-args:", "lint-variadic:")):
            if not allow_seed_metadata or body.strip():
                reject(line, "SYNTAX", "lint metadata is restricted to independent checker fixtures")
            key, _, values = comment.partition(":")
            for value in map(str.strip, values.split(",")):
                if key == "lint-args":
                    reg, _, how = value.partition(":")
                    if (reg not in REGISTERS or REGISTERS[reg][0] not in ARGUMENTS
                            or how not in ("s8", "u8", "s16", "u16", "s32", "u32")
                            or REGISTERS[reg][1] != int(how[1:])):
                        reject(line, "SYNTAX", f"invalid narrow argument {value!r}")
                    base = REGISTERS[reg][0]
                    if base in narrow:
                        reject(line, "SYNTAX", f"duplicate narrow argument {base}")
                    narrow[base] = (reg, how)
                elif re.fullmatch(SYMBOL, value):
                    variadic.add(value)
                else:
                    reject(line, "SYNTAX", f"invalid variadic symbol {value!r}")

        body = body.strip()
        # NASM reserves WAIT as an x87 mnemonic. Recognize the escaped
        # identifier only in positions that denote an ordinary ELF symbol.
        if body == "$wait:":
            body = "wait:"
        elif escaped := re.fullmatch(r"(global|extern|call)\s+\$wait(:function)?", body):
            body = f"{escaped[1]} wait{escaped[2] or ''}"
        if not body:
            continue
        directive, *fields = body.split()
        directive = directive.lower()
        if directive in ("section", "segment"):
            if not fields or fields[0] in sections:
                reject(line, "SYNTAX", "missing or repeated section name")
            section, *attributes = fields
            sections.add(section)
            options = set(map(str.lower, attributes))
            if section == ".note.GNU-stack":
                if ("noexec" not in options
                        or options - {"noexec", "noalloc", "nowrite", "progbits"}):
                    reject(line, "STACK_NOTE", "require a non-allocated, non-executable GNU-stack note")
                note = True
            elif match := re.fullmatch(rf"(\.rodata|\.data|\.bss)(?:\.{SYMBOL})?", section):
                required = DATA_SECTIONS[match[1]]
                if (not required <= options or any(option not in required
                        and not re.fullmatch(r"align=(?:1|2|4|8|16|32|64)", option)
                        for option in options)):
                    reject(line, "SYNTAX", f"unsupported data section attributes {attributes}")
            elif not re.fullmatch(rf"\.text(?:\.{SYMBOL})?", section):
                reject(line, "SYNTAX", f"unsupported section {section}")
            elif section != ".text" and not {"alloc", "exec"} <= options:
                reject(line, "SYNTAX", "named text section requires explicit alloc and exec attributes")
            elif any(option not in {"exec", "alloc", "nowrite", "progbits"}
                     and not re.fullmatch(r"align=(?:1|2|4|8|16|32|64)", option)
                     for option in options):
                reject(line, "SYNTAX", f"unsupported executable section attributes {attributes}")
            scope = ""
            section_start = True
            continue
        if directive == "bits":
            if fields != ["64"]:
                reject(line, "BITS_MODE", "only BITS 64 is supported")
            continue
        if directive == "default":
            if list(map(str.lower, fields)) != ["rel"]:
                reject(line, "SYNTAX", "only DEFAULT REL is supported")
            continue
        if directive in ("global", "extern"):
            declared = re.fullmatch(rf"({SYMBOL})(?::(function|data))?", " ".join(fields))
            if not declared:
                reject(line, "SYMBOL", f"invalid {directive} declaration")
            name, kind = declared.groups()
            if name in exports or name in externs or name in data_exports or name in data_externs:
                reject(line, "SYMBOL", f"duplicate declaration of {name}")
            if directive == "global":
                (data_exports if kind == "data" else exports)[name] = line
            else:
                (data_externs if kind == "data" else externs).add(name)
            continue
        if section is None:
            reject(line, "SYNTAX", "code requires an explicit executable section")
        if section == ".note.GNU-stack":
            reject(line, "STACK_NOTE", "GNU-stack section must be empty")
        if not section.startswith(".text"):
            if label := re.match(rf"({SYMBOL}):\s*", body):
                name = label[1]
                if name in data_labels or name in labels or name in externs or name in data_externs:
                    reject(line, "SYMBOL", f"duplicate label {name}")
                data_labels.add(name)
                body = body[label.end():]
            if body:
                check_data_directive(section, body, line)
            continue
        while match := re.match(rf"({LABEL}):\s*", body):
            name = match[1]
            if name.startswith("."):
                if not scope:
                    reject(line, "SYMBOL", "local label has no enclosing label")
                name = scope + name
            else:
                scope = name
            if name in labels or name in externs or name in data_labels or name in data_externs:
                reject(line, "SYMBOL", f"duplicate label {name}")
            if section_start and name not in exports:
                reject(line, "SYMBOL", "executable section must start at an exported entry")
            labels[name] = len(instructions)
            section_start = False
            body = body[match.end():]
        if not body:
            continue
        if section_start:
            reject(line, "SYMBOL", "instruction outside an exported entry")
        match = re.fullmatch(r"([a-zA-Z][a-zA-Z0-9]*)\s*(.*)", body)
        if not match:
            reject(line, "SYNTAX", f"unsupported NASM statement {body!r}")
        opcode = match[1].lower()
        if opcode in DATA:
            reject(line, "EXEC_DATA", f"{opcode} can emit unchecked bytes in executable code")
        operands = tuple(map(str.strip, match[2].split(","))) if match[2] else ()
        instructions.append(Instruction(line, opcode, operands, scope))

    if not note:
        reject(1, "STACK_NOTE", "missing section .note.GNU-stack noexec")
    if not exports:
        reject(1, "SYMBOL", "no exported entry")
    if variadic - (set(exports) | externs):
        reject(1, "SYMBOL", "variadic target must be declared")
    for name, line in data_exports.items():
        if name not in data_labels:
            reject(line, "SYMBOL", f"data export {name} has no data label")
    entries = {}
    for name, line in exports.items():
        if name not in labels or labels[name] == len(instructions):
            reject(line, "SYMBOL", f"export {name} has no instructions")
        if labels[name] in entries.values():
            reject(line, "SYMBOL", f"export {name} aliases another entry")
        entries[name] = labels[name]
    return Program(instructions, entries, labels, externs, narrow, variadic,
                   set(data_exports), data_externs)


def check_data_directive(section, body, line):
    if re.fullmatch(r"alignb? (?:1|2|4|8|16|32|64)", body, re.I):
        return
    if section == ".bss" or section.startswith(".bss."):
        pattern = r"res[bwdq]\s+[1-9][0-9]*"
    else:
        value = rf'(?:{INTEGER}|"[ -!#-~]*"|\x27[ -&(-~]*\x27)'
        pattern = rf"d[bwdq]\s+{value}(?:\s*,\s*{value})*"
    if not re.fullmatch(pattern, body, re.I):
        reject(line, "EXEC_DATA", "only literal data and bounded alignment are supported outside text")


def merge(a, b, line):
    if a.rsp != b.rsp:
        reject(line, "STACK_BALANCE", "stack offsets disagree at control-flow join")
    if a.rbp_frame != b.rbp_frame:
        reject(line, "STACK_ACCESS", "rbp frame identities disagree at control-flow join")
    if a.x87_depth != b.x87_depth:
        reject(line, "X87_RETURN", "x87 depths disagree at control-flow join")
    return State(
        rsp=a.rsp,
        rbp_frame=a.rbp_frame,
        dirty=a.dirty | b.dirty,
        saved=a.saved & b.saved,
        slots=a.slots & b.slots,
        df=a.df or b.df,
        x87_depth=a.x87_depth,
        control_dirty=a.control_dirty | b.control_dirty,
        pending_args=a.pending_args | b.pending_args,
        variadic_al_ready=a.variadic_al_ready and b.variadic_al_ready,
        r10_ready=a.r10_ready and b.r10_ready,
        syscall_clobbers=a.syscall_clobbers | b.syscall_clobbers,
        process_entry=a.process_entry,
        caller_stack_arg=a.caller_stack_arg,
        tls_self=a.tls_self,
        callback_table_registers=a.callback_table_registers & b.callback_table_registers,
        callback_registers=a.callback_registers & b.callback_registers,
    )


def check_operands(ins, count):
    if len(ins.operands) not in count:
        reject(ins.line, "INSTRUCTION", f"unexpected operand count for {ins.opcode}")
    if any(re.search(r"\b(?:[yz]mm[0-9]+|mm[0-7])\b", value, re.I) for value in ins.operands):
        reject(ins.line, "ISA_BASELINE", "non-SSE2 vector or MMX register")
    return tuple(operand(value, ins.line) for value in ins.operands)


def stack_location(state, op, width, line, *, write):
    stack_regs = set(op.address) & {"rsp", "rbp"}
    if not stack_regs:
        return None
    match = re.fullmatch(r"(rsp|rbp)(?:\s*([+-])\s*(0[xX][0-9A-Fa-f]+|[0-9]+))?",
                         op.value, re.I)
    if not match or not width:
        reject(line, "STACK_ACCESS", "require fixed stack address and known access width")
    base = state.rsp if match[1].lower() == "rsp" else state.rbp_frame
    if base is None:
        reject(line, "STACK_ACCESS", "rbp does not have a known frame address")
    offset = integer((match[2] or "+") + (match[3] or "0"))
    address = base + offset
    if not write and width == 8 and match[1].lower() == "rsp":
        if ((state.process_entry and address == 0)
                or (state.context_save and state.rsp == 0 and address == 0)
                or (state.caller_stack_arg and address == 8)):
            return None
    if address < state.rsp or address + width > 0:
        reject(line, "STACK_ACCESS", "stack access is outside the allocated frame")
    return address


def read_registers(state, regs, line, extension=None, allow_stack_register=False):
    for reg in regs:
        if reg in state.syscall_clobbers:
            reject(line, "SYSCALL_CLOBBER", f"read of {reg} after syscall clobbered it")
        if reg in state.pending_args and reg != extension:
            reject(line, "NARROW_ARG", f"read of {reg} before explicit argument extension")
        if not allow_stack_register and (reg == "rsp" or reg == "rbp" and state.rbp_frame is not None):
            reject(line, "STACK_ACCESS", f"unsupported use of frame address in {reg}")


def access_memory(state, op, width, line, *, write=False):
    read_registers(state, op.address, line, allow_stack_register=True)
    if op.segment and (not state.tls_self or write or width != 8):
        reject(line, "TLS_ADDRESS", "the FS self pointer requires a qword load")
    address = stack_location(state, op, width, line, write=write)
    if not write or address is None:
        return state, address
    if any(address < slot + 8 and slot < address + width for slot, _ in state.saved):
        reject(line, "STACK_ACCESS", "write overlaps saved register")
    slots = frozenset((slot, kind) for slot, kind in state.slots
                      if not (address < slot + (4 if kind == "mxcsr" else 2)
                              and slot < address + width))
    return replace(state, slots=slots), address


def write_gpr(state, op, line, *, al=None, restore=None, rbp_frame=None):
    reg = op.base
    if reg == "rsp":
        reject(line, "STACK_ACCESS", "unsupported write to stack pointer")
    whole = op.width >= 32
    dirty = state.dirty
    if reg in CALLEE:
        dirty = dirty - {reg} if restore == reg else dirty | {reg}
    return replace(
        state, dirty=dirty,
        rbp_frame=rbp_frame if reg == "rbp" else state.rbp_frame,
        pending_args=state.pending_args - {reg} if whole else state.pending_args,
        syscall_clobbers=state.syscall_clobbers - {reg} if whole else state.syscall_clobbers,
        variadic_al_ready=(al is not None and 0 <= al <= 8)
        if reg == "rax" and op.value != "ah" else state.variadic_al_ready,
        r10_ready=((op.width == 64 if state.caller_stack_arg else whole or state.r10_ready)
                   if reg == "r10" else state.r10_ready),
        callback_table_registers=state.callback_table_registers - {reg},
        callback_registers=state.callback_registers - {reg},
    )


def stack_adjust(state, rsp, line):
    if rsp > 0:
        reject(line, "STACK_BALANCE", "stack pointer crosses the entry frame")
    return replace(state, rsp=rsp,
                   saved=frozenset((address, reg) for address, reg in state.saved if address >= rsp),
                   slots=frozenset((address, kind) for address, kind in state.slots if address >= rsp))


def extend_argument(state, program, opcode, dest, src):
    if src.kind != "gpr" or src.base not in state.pending_args or dest.kind != "gpr":
        return None
    reg, how = program.narrow[src.base]
    if src.value != reg:
        return None
    if how == "u32" and opcode == "mov" and dest.width == 32:
        return src.base
    if how.startswith("u") and opcode == "movzx" and dest.width >= 32:
        return src.base
    if how.startswith("s") and dest.width == 64 and opcode == ("movsxd" if how == "s32" else "movsx"):
        return src.base
    return None


def width(op):
    return op.size if op.kind == "mem" else op.width // 8


def transfer_data(state, program, ins):
    opcode, line = ins.opcode, ins.line
    unary = opcode in UNARY
    operands = check_operands(ins, {1} if unary else {2})
    dest, *rest = operands
    src = rest[0] if rest else None
    if opcode in ("add", "sub") and dest.value == "rsp" and src.kind == "imm":
        delta = integer(src.value)
        if not 0 <= delta <= 0x7fff_ffff:
            reject(line, "STACK_ACCESS", "require nonnegative signed 32-bit stack adjustment")
        return stack_adjust(state, state.rsp + (delta if opcode == "add" else -delta), line)
    if opcode == "mov" and (dest.value, src.value) == ("rbp", "rsp"):
        return write_gpr(state, dest, line, rbp_frame=state.rsp)
    if opcode == "mov" and (dest.value, src.value) == ("rsp", "rbp"):
        if state.rbp_frame is None:
            reject(line, "STACK_ACCESS", "rbp does not have a known frame address")
        return stack_adjust(state, state.rbp_frame, line)
    is_comparison = opcode in ("cmp", "test")
    is_move = opcode in MOVES | SSE_MOVE
    zero_idiom = opcode == "xor" and dest.kind == "gpr" and dest == src
    if opcode in SSE_ALU and dest.kind != "xmm":
        reject(line, "ISA_BASELINE", "only the SSE2 XMM form is supported")
    if opcode in SSE_MOVE and not any(op.kind == "xmm" for op in operands):
        reject(line, "INSTRUCTION", f"only the SSE2 register form of {opcode} is supported")
    if opcode in MOVES | ARITH | UNARY and any(op.kind in {"xmm", "x87"} for op in operands):
        reject(line, "INSTRUCTION", "unsupported use of vector or x87 register")
    if src:
        if src.kind == "gpr" and not zero_idiom:
            extension = extend_argument(state, program, opcode, dest, src)
            read_registers(state, (src.base,), line, extension)
        elif src.kind == "mem":
            process_stack_address = (state.process_entry and state.rsp == 0 and
                                     re.fullmatch(r"rsp\s*\+\s*8", src.value, re.I))
            if opcode == "lea":
                if src.segment:
                    reject(line, "TLS_ADDRESS", "LEA does not apply an FS segment base")
                record = (program.kernel_stack_records or {}).get((dest.value, src.value))
                context_stack_address = (state.context_save and state.rsp == 0
                                         and dest.value == "rax" and src.value == "rsp + 8")
                modeled_frame_address = process_stack_address or context_stack_address or program.varargs_frame or record
                if set(src.address) & {"rsp", "rbp"} and not modeled_frame_address:
                    reject(line, "STACK_ACCESS", "stack address escape is unsupported")
                if record:
                    state, _ = access_memory(state, src, record.extent, line, write=True)
                read_registers(state, src.address, line, allow_stack_register=bool(modeled_frame_address))
            else:
                src_width = src.size if opcode in ("movzx", "movsx") else width(src) or width(dest)
                state, _ = access_memory(state, src, src_width, line)
        elif src.kind == "symbol":
            reject(line, "INSTRUCTION", "symbol immediates are unsupported")
    if dest.kind == "mem":
        size = width(dest) or (width(src) if src else 0)
        if opcode in {"movss", "movd"}:
            size = 4
        elif opcode in {"movsd", "movq"}:
            size = 8
        # An immediate AND/OR confined to the six MXCSR status bits leaves
        # the saved control bits intact. All other writes invalidate the slot.
        preserve = False
        if size == 4 and opcode in {"and", "or"} and src.kind == "imm":
            value = integer(src.value) & 0xffff_ffff
            preserve = ((value & 0xffff_ffc0) == 0xffff_ffc0 if opcode == "and"
                        else (value & 0xffff_ffc0) == 0)
        original_slots = state.slots
        state, address = access_memory(state, dest, size, line, write=not is_comparison)
        if preserve and (address, "mxcsr") in original_slots:
            state = replace(state, slots=state.slots | {(address, "mxcsr")})
        return state
    if dest.kind == "xmm":
        return state
    if dest.kind != "gpr":
        reject(line, "INSTRUCTION", "unsupported destination operand")
    if not is_move and not zero_idiom:
        read_registers(state, (dest.base,), line)
    if is_comparison:
        return state
    al = None
    if zero_idiom and dest.value != "ah":
        al = 0
    elif opcode == "mov" and src.kind == "imm":
        al = integer(src.value) & 255
    # movzx/movsx into 32- or 64-bit destinations also overwrites all high bits.
    updated = write_gpr(state, dest, line, al=al)
    if program.callback_dispatch and dest.width == 64:
        if (program.callback_table and opcode == "lea" and src.kind == "mem"
                and src.value == "__al_atexit_state"):
            updated = replace(updated, callback_table_registers=updated.callback_table_registers | {dest.base})
        if opcode == "mov":
            slot = (src.kind == "mem" and re.fullmatch(
                r"(\w+)\s*\+\s*rax\s*\*\s*8\s*\+\s*8", src.value))
            if ((slot and slot[1] in state.callback_table_registers) or
                    (src.kind == "gpr" and src.width == 64 and src.base in state.callback_registers)):
                updated = replace(updated, callback_registers=updated.callback_registers | {dest.base})
    return updated


def transfer_control(state, program, ins, syscall_boundary, x87_return):
    opcode, line = ins.opcode, ins.line
    if opcode == "ret":
        if ins.operands:
            reject(line, "RETURN_FORM", "plain near ret is required")
        if state.rsp:
            reject(line, "STACK_BALANCE", f"return with rsp offset {state.rsp}")
        if state.dirty:
            reject(line, "CALLEE_SAVED", "return with modified " + ", ".join(sorted(state.dirty)))
        if state.df:
            reject(line, "DF_RETURN", "DF may be set on return")
        if state.x87_depth != x87_return:
            reject(line, "X87_RETURN", "unexpected live x87 values on return")
        for kind, rule in (("mxcsr", "MXCSR"), ("x87", "X87_CONTROL")):
            if kind in state.control_dirty and not program.fenv_controls:
                reject(line, rule, f"{kind} control state may be modified on return")
        return state
    if opcode == "call":
        if len(ins.operands) != 1:
            reject(line, "CONTROL_FLOW", "call requires one declared target")
        target = ins.operands[0]
        callback = target == "rax" and program.callback_dispatch and target in state.callback_registers
        if not callback and target not in (set(program.entries) | program.externs):
            reject(line, "CONTROL_FLOW", "call target is neither a declared symbol nor a modeled callback")
        if (target in program.externs and program.external_signatures is not None
                and target not in program.external_signatures):
            reject(line, "CALL_SIGNATURE", f"no modeled ABI signature for {target}")
        if state.df:
            reject(line, "DF_CALL", "DF may be set at call")
        if state.x87_depth:
            reject(line, "X87_CALL", "x87 stack must be empty at call")
        if target in program.variadic and not state.variadic_al_ready:
            reject(line, "VARIADIC_AL", "variadic call needs a defined AL value from 0 through 8")
        entry_alignment = 0 if state.process_entry else 8
        if (entry_alignment + state.rsp) % 16:
            reject(line, "STACK_ALIGNMENT", "rsp must be 16-byte aligned before call")
        return replace(state, variadic_al_ready=False, r10_ready=False,
                       callback_table_registers=state.callback_table_registers & CALLEE,
                       callback_registers=state.callback_registers & CALLEE)
    if opcode in JCC or opcode == "jmp":
        if len(ins.operands) != 1 or not re.fullmatch(LABEL, ins.operands[0]):
            reject(line, "CONTROL_FLOW", "only direct jumps to local code are supported")
        return state
    if opcode in {"sysenter", "int", "int3", "iret", "iretq", "sysret", "sysretq"}:
        reject(line, "SYSCALL_BOUNDARY", f"{opcode} is outside the supported syscall boundary")
    check_operands(ins, {0})
    if not syscall_boundary:
        reject(line, "SYSCALL_BOUNDARY", "syscall is only allowed in the private kernel boundary")
    if not state.r10_ready and not program.signal_restorer:
        reject(line, "SYSCALL_ARG4", "establish Linux syscall argument 4 in r10")
    return replace(state, variadic_al_ready=False, r10_ready=False,
                   syscall_clobbers=state.syscall_clobbers | {"rcx", "r11"})


def transfer(state, program, ins, syscall_boundary, x87_return):
    opcode, line = ins.opcode, ins.line
    if opcode.startswith(("v", "aes")) or opcode in AFTER_SSE2:
        reject(line, "ISA_BASELINE", f"{opcode} exceeds the SSE2 baseline")
    if opcode in MOVES | ARITH | UNARY | SSE_MOVE | SSE_ALU | {"cmp", "test"}:
        return transfer_data(state, program, ins)
    if opcode == "div":
        (divisor,) = check_operands(ins, {1})
        if divisor.kind != "gpr" or divisor.width != 64:
            reject(line, "INSTRUCTION", "only unsigned division by a full-width GPR is modeled")
        read_registers(state, ("rax", "rdx", divisor.base), line)
        state = write_gpr(state, operand("rax", line), line)
        return write_gpr(state, operand("rdx", line), line)
    if opcode in JCC | {"ret", "call", "jmp", "syscall", "sysenter", "int", "int3",
                        "iret", "iretq", "sysret", "sysretq"}:
        return transfer_control(state, program, ins, syscall_boundary, x87_return)
    if opcode in {"retf", "retn", "retfq"}:
        reject(line, "RETURN_FORM", "plain near ret is required")
    if opcode.startswith("j") or opcode.startswith("loop"):
        reject(line, "CONTROL_FLOW", f"unsupported transfer {opcode}")
    if opcode in {"nop", "cld", "std", "leave"}:
        check_operands(ins, {0})
        if opcode == "leave":
            if state.rbp_frame is None:
                reject(line, "STACK_ACCESS", "leave needs a known frame address")
            state = stack_adjust(state, state.rbp_frame, line)
            return transfer(state, program, replace(ins, opcode="pop", operands=("rbp",)),
                            syscall_boundary, x87_return)
        return state if opcode == "nop" else replace(state, df=opcode == "std")
    if opcode == "ud2":
        check_operands(ins, {0})
        return state
    if opcode in {"push", "pop"}:
        (reg,) = check_operands(ins, {1})
        if reg.kind != "gpr" or reg.width != 64 or reg.base == "rsp":
            reject(line, "STACK_ACCESS", "only whole general registers can be pushed or popped")
        if opcode == "push":
            read_registers(state, (reg.base,), line,
                           allow_stack_register=reg.base == "rbp" and state.rbp_frame is None)
            state = stack_adjust(state, state.rsp - 8, line)
            marker = reg.base if reg.base in CALLEE and reg.base not in state.dirty else ""
            return replace(state, saved=state.saved | {(state.rsp, marker)})
        if not any(address == state.rsp for address, _ in state.saved):
            reject(line, "STACK_ACCESS", "pop has no matching push at this stack offset")
        restore = reg.base if (state.rsp, reg.base) in state.saved else None
        state = stack_adjust(state, state.rsp + 8, line)
        return write_gpr(state, reg, line, restore=restore)
    if opcode in {"fld1", "fldz", "fld", "fst", "fstp"}:
        args = check_operands(ins, {0} if opcode in {"fld1", "fldz"} else {1})
        if args:
            arg = args[0]
            if arg.kind == "mem":
                state, _ = access_memory(state, arg, arg.size, line, write=opcode != "fld")
            elif arg.kind != "x87":
                reject(line, "INSTRUCTION", "require x87 register or memory")
            elif int(arg.base[-1]) >= state.x87_depth:
                reject(line, "X87_RETURN", "use of empty x87 register")
        if opcode == "fst" and not state.x87_depth:
            reject(line, "X87_RETURN", "store from empty x87 stack")
        depth = state.x87_depth + (0 if opcode == "fst" else -1 if opcode == "fstp" else 1)
        if not 0 <= depth <= 8:
            reject(line, "X87_RETURN", "x87 stack underflow or overflow")
        return replace(state, x87_depth=depth)
    if opcode in {"fnstenv", "fldenv", "fnstsw"}:
        if not program.fenv_access:
            reject(line, "X87_CONTROL", f"{opcode} is reserved for the floating environment API")
        (op,) = check_operands(ins, {1})
        if opcode == "fnstsw":
            if op.kind != "gpr" or op.value != "ax":
                reject(line, "INSTRUCTION", "floating status is read through AX")
            return write_gpr(state, op, line)
        if op.kind != "mem":
            reject(line, "INSTRUCTION", "x87 environment requires a 28-byte memory object")
        store = opcode == "fnstenv"
        state, address = access_memory(state, op, 28, line, write=store)
        dirty = state.control_dirty | {"x87"}
        if store:
            slots = state.slots
            if address is not None and "x87" not in state.control_dirty:
                slots |= {(address, "x87")}
            return replace(state, control_dirty=dirty, slots=slots)
        if (address, "x87") in state.slots:
            dirty -= {"x87"}
        return replace(state, control_dirty=dirty)
    if opcode in {"ldmxcsr", "stmxcsr", "fldcw", "fstcw", "fnstcw"}:
        (op,) = check_operands(ins, {1})
        if op.kind != "mem":
            reject(line, "INSTRUCTION", "control-state operation requires memory")
        mxcsr = opcode in {"ldmxcsr", "stmxcsr"}
        kind = "mxcsr" if mxcsr else "x87"
        store = opcode in {"stmxcsr", "fstcw", "fnstcw"}
        state, address = access_memory(state, op, 4 if mxcsr else 2, line, write=store)
        if store:
            if address is not None and kind not in state.control_dirty:
                return replace(state, slots=state.slots | {(address, kind)})
            return state
        dirty = state.control_dirty | {kind}
        if (address, kind) in state.slots:
            dirty -= {kind}
        return replace(state, control_dirty=dirty)
    if opcode in {"finit", "fninit"}:
        check_operands(ins, {0})
        return replace(state, x87_depth=0, control_dirty=state.control_dirty | {"x87"})
    reject(line, "INSTRUCTION", f"unsupported instruction {opcode}")


def verify(program, syscall_boundary, x87_return):
    starts = sorted(program.entries.values())
    names = {index: name for name, index in program.entries.items()}
    if starts[0] != 0:
        reject(1, "CONTROL_FLOW", "executable instructions precede the first exported entry")
    for start, stop in zip(starts, [*starts[1:], len(program.instructions)]):
        noreturn = names[start] in program.noreturn
        states = {start: State(pending_args=frozenset(program.narrow),
                               process_entry=program.process_entry,
                               caller_stack_arg=program.caller_stack_arg, tls_self=program.tls_self,
                               context_save=program.context_save, callback_registers=(frozenset({program.comparator_argument})
                                                   if program.comparator_argument else frozenset()))}
        work = deque([start])
        terminal = False
        while work:
            index = work.popleft()
            ins = program.instructions[index]
            state = transfer(states[index], program, ins, syscall_boundary, x87_return)
            if ins.opcode == "ret":
                if noreturn:
                    reject(ins.line, "CONTROL_FLOW", "non-returning entry cannot return")
                terminal = True
                continue
            if ins.opcode == "ud2":
                prior = program.instructions[index - 1] if index > start else None
                fallback_trap = (prior is not None and prior.opcode == "call"
                                 and prior.operands[0] in program.noreturn
                                 and index not in program.labels.values())
                if not noreturn and not fallback_trap:
                    reject(ins.line, "CONTROL_FLOW", "trap requires a non-returning entry")
                terminal = terminal or noreturn
                continue
            if ins.opcode == "call" and ins.operands[0] in program.noreturn:
                terminal = terminal or noreturn
                # A non-returning call may retain an explicit hardware trap if
                # its callee unexpectedly returns.
                if not (index + 1 < stop and program.instructions[index + 1].opcode == "ud2"):
                    continue
            successors = []
            if ins.opcode in JCC or ins.opcode == "jmp":
                label = ins.operands[0]
                target = (ins.scope + label) if label.startswith(".") else label
                branch = program.labels.get(target)
                if branch is None or not start <= branch < stop:
                    reject(ins.line, "CONTROL_FLOW", f"unresolved or cross-function branch to {label}")
                successors.append(branch)
            if ins.opcode != "jmp":
                successors.append(index + 1)
            for successor in successors:
                if successor >= stop:
                    reject(ins.line, "CONTROL_FLOW", "execution can fall through the function boundary")
                current = states.get(successor)
                updated = state if current is None else merge(current, state, program.instructions[successor].line)
                if updated != current:
                    states[successor] = updated
                    work.append(successor)
        for index in range(start, stop):
            if index not in states:
                reject(program.instructions[index].line, "CONTROL_FLOW", "unreachable executable instruction")
        if not terminal:
            reject(program.instructions[start].line, "CONTROL_FLOW", "entry has no reachable exit")


def check_file(path, function, fixture_syscall):
    resolved = path.resolve()
    relative = resolved.relative_to(ROOT) if resolved.is_relative_to(ROOT) else resolved
    parts = relative.parts
    in_seed = parts[:2] == ("tests", "seeded-bugs")
    runtime = parts[:2] == RUNTIME
    relative_runtime = Path(*parts[2:]).with_suffix("").as_posix() if runtime else None
    private = relative_runtime in PRIVATE_FUNCTIONS
    internal = parts[:3] == (*RUNTIME, "internal")
    app = parts[:1] == ("apps",)
    if fixture_syscall and not in_seed:
        reject(1, "SYSCALL_BOUNDARY", "fixture boundary option is restricted to tests/seeded-bugs")
    if function is None and (parts[:1] in (("src",), ("ext",))) and not private:
        function = path.stem
    narrow = {}
    variadic = set()
    external_signatures = set()
    noreturn = set()
    x87_return = 0
    if function is not None or private or app:
        from spec import SpecError, check_comment_header, load_project
        try:
            project = load_project(ROOT)
            if function is not None:
                spec = project.functions.get(function)
                if spec is None:
                    reject(1, "SPEC_HEADER", f"no function specification for {function}")
                check_comment_header(path, spec)
                for arg in spec.abi.narrow_args:
                    reg, how = arg.split(":")
                    narrow[REGISTERS[reg][0]] = (reg, how)
                if spec.prototype.startswith("long double "):
                    x87_return = 1
            external_signatures.update(project.functions)
            external_signatures.update(Path(name).name for name in PRIVATE_FUNCTIONS)
            external_signatures.difference_update({"_start", "__al_rt_sigreturn"})
            noreturn = PRIVATE_NORETURN | {name for name, spec in project.functions.items()
                                          if spec.abi.noreturn}
            variadic = {name for name, spec in project.functions.items() if spec.abi.variadic}
        except SpecError as error:
            reject(1, "SPEC_HEADER", str(error))
    program = parse(path.read_text(), narrow, set(), in_seed)
    if not in_seed or function is not None:
        program.external_signatures = external_signatures
    program.variadic.update(variadic & (set(program.entries) | program.externs))
    program.noreturn = frozenset(noreturn)
    program.process_entry = relative_runtime == "rt/_start"
    program.signal_restorer = relative_runtime == "internal/__al_rt_sigreturn"
    program.caller_stack_arg = relative_runtime == "internal/__al_syscall"
    program.tls_self = relative_runtime == "rt/__errno_location"
    program.callback_table = relative_runtime == "stdlib/exit"
    program.comparator_argument = COMPARATOR_ARGUMENTS.get(function)
    program.callback_dispatch = program.callback_table or program.comparator_argument is not None
    program.fenv_access = relative_runtime in {
        f"fenv/{name}" for name in ("feclearexcept", "fegetenv", "feholdexcept", "fesetenv", "fetestexcept")
    }
    program.fenv_controls = relative_runtime in {"fenv/feholdexcept", "fenv/fesetenv", "fenv/fesetround"}
    program.kernel_stack_records = KERNEL_STACK_RECORDS.get(relative_runtime)
    if program.kernel_stack_records:
        instructions = program.instructions
        for index, ins in enumerate(instructions):
            if ins.opcode != "lea" or len(ins.operands) != 2:
                continue
            dest, src = (operand(value, ins.line) for value in ins.operands)
            record = program.kernel_stack_records.get((dest.value, src.value))
            if record is None:
                continue
            start = index - len(record.setup)
            preceding = tuple((prior.opcode, prior.operands) for prior in instructions[max(0, start):index])
            for finish in record.finishes:
                call_index = index + len(finish) + 1
                following = tuple((later.opcode, later.operands) for later in instructions[index + 1:call_index + 1])
                if (preceding == record.setup and following == (*finish, ("call", ("__al_syscall",)))
                        and not any(start < target <= call_index for target in program.labels.values())):
                    break
            else:
                reject(ins.line, "STACK_ACCESS", "bounded kernel stack record must go directly to its modeled syscall")
    if relative_runtime in VARARGS_WRAPPERS:
        target, fixed, register = VARARGS_WRAPPERS[relative_runtime]
        expected = [("push", ("rbp",)), ("mov", ("rbp", "rsp")), ("sub", ("rsp", "208"))]
        expected += [("mov", (f"[rsp + {32 + index * 8}]", argument))
                     for index, argument in enumerate(("rdi", "rsi", "rdx", "rcx", "r8", "r9"))]
        if target in {"vprintf", "vfprintf", "vsprintf", "vsnprintf"}:
            expected += [("movdqa", (f"[rsp + {80 + index * 16}]", f"xmm{index}"))
                         for index in range(8)]
        expected += [
            ("mov", ("dword [rsp]", str(fixed * 8))),
            ("mov", ("dword [rsp + 4]", "48")),
            ("lea", ("rax", "[rbp + 16]")), ("mov", ("[rsp + 8]", "rax")),
            ("lea", ("rax", "[rsp + 32]")), ("mov", ("[rsp + 16]", "rax")),
            ("lea", (register, "[rsp]")), ("call", (target,)),
            ("add", ("rsp", "208")), ("pop", ("rbp",)), ("ret", ()),
        ]
        if [(ins.opcode, ins.operands) for ins in program.instructions] != expected:
            reject(1, "STACK_ACCESS", "variadic wrapper must pass its bounded SysV register-save record")
        program.varargs_frame = True
    if program.process_entry:
        program.external_signatures.add("main")
    if program.external_data - (PRIVATE_DATA.keys() if runtime or app else set()):
        reject(1, "SYMBOL", "no modeled ABI for external data symbol")
    if any(name not in PRIVATE_DATA or PRIVATE_DATA[name] != relative_runtime
           for name in program.data_symbols):
        reject(1, "SYMBOL", "no modeled ABI for exported data symbol")
    if private and set(program.entries) != {path.stem}:
        reject(1, "SYMBOL", f"expected exactly one private export named {path.stem}")
    if program.signal_restorer:
        sequence = [(ins.opcode, ins.operands) for ins in program.instructions]
        if sequence != [("mov", ("eax", "15")), ("syscall", ()), ("ud2", ())]:
            reject(1, "SYSCALL_BOUNDARY", "signal restorer must issue Linux rt_sigreturn and then trap")
    if function is not None and set(program.entries) != {function}:
        reject(1, "SYMBOL", f"expected exactly one export named {function}")
    if relative_runtime in {"setjmp/setjmp", "setjmp/sigsetjmp"}:
        prefix = JUMP_SAVE if function == "setjmp" else (("movsxd", ("rsi", "esi")), *JUMP_SAVE)
        sequence = tuple((ins.opcode, ins.operands) for ins in program.instructions)
        frame_lea = ("lea", ("rax", "[rsp + 8]"))
        if (sequence[:len(prefix)] != prefix or sequence.count(frame_lea) != 1
                or any(0 < label < len(prefix) for label in program.labels.values())):
            reject(1, "CONTROL_FLOW", "context save must capture the caller registers and return point at entry")
        program.context_save = True
    if relative_runtime == "setjmp/longjmp":
        sequence = tuple((ins.opcode, ins.operands) for ins in program.instructions)
        if sequence != JUMP_RESTORE or program.labels != {"longjmp": 0, "longjmp.restore": 4}:
            reject(1, "CONTROL_FLOW", "context resume must restore the exact saved registers and transfer to the saved PC")
    else:
        verify(program, internal or fixture_syscall, x87_return)
    # NASM is the authority for operand encodings. Preprocessor directives and
    # data emission were already rejected, so it assembles exactly this subset.
    with tempfile.TemporaryDirectory(prefix="al-lint-") as directory:
        result = subprocess.run(["nasm", "-f", "elf64", "-Wall", "-Werror", "-Wno-reloc-rel-dword",
                                 "-I", "include/asm/", "-o",
                                 str(Path(directory) / "test.o"), str(resolved)],
                                cwd=ROOT, capture_output=True, text=True)
    if result.returncode:
        diagnostic = result.stderr.strip().splitlines()
        first = diagnostic[0] if diagnostic else "NASM assembly failed"
        match = re.search(r":(\d+):\s*(.*)", first)
        reject(int(match[1]) if match else 1, "SYNTAX", match[2] if match else first)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--function", help="require this function's generated comment header and sole export")
    parser.add_argument("--fixture-syscall-boundary", action="store_true",
                        help="authorize syscall analysis for a seed under tests/seeded-bugs")
    parser.add_argument("paths", type=Path, nargs="+")
    args = parser.parse_args()
    failed = False
    for path in args.paths:
        try:
            check_file(path, args.function, args.fixture_syscall_boundary)
        except Violation as error:
            print(f"{path}:{error.line}: {error.rule}: {error.message}", file=sys.stderr)
            failed = True
        except (OSError, UnicodeError) as error:
            print(f"lint: {path}: {error}", file=sys.stderr)
            return 2
    return int(failed)
