"""Conservative verifier for the Phase 0 subset of NASM x86-64."""

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
                     "psubw", "psubd", "psubq", "pslldq", "psrldq"))
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


@dataclass
class Program:
    instructions: list[Instruction]
    entries: dict[str, int]
    labels: dict[str, int]
    externs: set[str]
    narrow: dict[str, tuple[str, str]]
    variadic: set[str]
    external_signatures: set[str] | None = None


def parse(source, narrow, variadic, allow_seed_metadata):
    instructions = []
    labels = {}
    exports = {}
    externs = set()
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
            declared = re.fullmatch(rf"{SYMBOL}(?::function)?", " ".join(fields))
            if not declared:
                reject(line, "SYMBOL", f"invalid {directive} declaration")
            name = declared[0].partition(":")[0]
            if name in exports or name in externs:
                reject(line, "SYMBOL", f"duplicate declaration of {name}")
            if directive == "global":
                exports[name] = line
            else:
                externs.add(name)
            continue
        if section is None:
            reject(line, "SYNTAX", "code requires an explicit executable section")
        if section == ".note.GNU-stack":
            reject(line, "STACK_NOTE", "GNU-stack section must be empty")
        while match := re.match(rf"({LABEL}):\s*", body):
            name = match[1]
            if name.startswith("."):
                if not scope:
                    reject(line, "SYMBOL", "local label has no enclosing label")
                name = scope + name
            else:
                scope = name
            if name in labels or name in externs:
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
    entries = {}
    for name, line in exports.items():
        if name not in labels or labels[name] == len(instructions):
            reject(line, "SYMBOL", f"export {name} has no instructions")
        if labels[name] in entries.values():
            reject(line, "SYMBOL", f"export {name} aliases another entry")
        entries[name] = labels[name]
    return Program(instructions, entries, labels, externs, narrow, variadic)


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
    )


def check_operands(ins, count):
    if len(ins.operands) not in count:
        reject(ins.line, "INSTRUCTION", f"unexpected operand count for {ins.opcode}")
    if any(re.search(r"\b(?:[yz]mm[0-9]+|mm[0-7])\b", value, re.I) for value in ins.operands):
        reject(ins.line, "ISA_BASELINE", "non-SSE2 vector or MMX register")
    return tuple(operand(value, ins.line) for value in ins.operands)


def stack_location(state, op, width, line):
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
    address = stack_location(state, op, width, line)
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
        r10_ready=(whole or state.r10_ready) if reg == "r10" else state.r10_ready,
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
            if opcode == "lea" and set(src.address) & {"rsp", "rbp"}:
                reject(line, "STACK_ACCESS", "stack address escape is unsupported")
            if opcode == "lea":
                read_registers(state, src.address, line)
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
        state, _ = access_memory(state, dest, size, line, write=not is_comparison)
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
    return write_gpr(state, dest, line, al=al)


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
            if kind in state.control_dirty:
                reject(line, rule, f"{kind} control state may be modified on return")
        return state
    if opcode == "call":
        if (len(ins.operands) != 1
                or ins.operands[0] not in (set(program.entries) | program.externs)):
            reject(line, "CONTROL_FLOW", "only direct calls to declared symbols are supported")
        target = ins.operands[0]
        if (target in program.externs and program.external_signatures is not None
                and target not in program.external_signatures):
            reject(line, "CALL_SIGNATURE", f"no modeled ABI signature for {target}")
        if state.df:
            reject(line, "DF_CALL", "DF may be set at call")
        if state.x87_depth:
            reject(line, "X87_CALL", "x87 stack must be empty at call")
        if target in program.variadic and not state.variadic_al_ready:
            reject(line, "VARIADIC_AL", "variadic call needs a defined AL value from 0 through 8")
        if (8 + state.rsp) % 16:
            reject(line, "STACK_ALIGNMENT", "rsp must be 16-byte aligned before call")
        return replace(state, variadic_al_ready=False, r10_ready=False)
    if opcode in JCC or opcode == "jmp":
        if len(ins.operands) != 1 or not re.fullmatch(LABEL, ins.operands[0]):
            reject(line, "CONTROL_FLOW", "only direct jumps to local code are supported")
        return state
    if opcode in {"sysenter", "int", "int3", "iret", "iretq", "sysret", "sysretq"}:
        reject(line, "SYSCALL_BOUNDARY", f"{opcode} is outside the supported syscall boundary")
    check_operands(ins, {0})
    if not syscall_boundary:
        reject(line, "SYSCALL_BOUNDARY", "syscall is only allowed in the private kernel boundary")
    if not state.r10_ready:
        reject(line, "SYSCALL_ARG4", "establish Linux syscall argument 4 in r10")
    return replace(state, variadic_al_ready=False, r10_ready=False,
                   syscall_clobbers=state.syscall_clobbers | {"rcx", "r11"})


def transfer(state, program, ins, syscall_boundary, x87_return):
    opcode, line = ins.opcode, ins.line
    if opcode.startswith(("v", "aes")) or opcode in AFTER_SSE2:
        reject(line, "ISA_BASELINE", f"{opcode} exceeds the SSE2 baseline")
    if opcode in MOVES | ARITH | UNARY | SSE_MOVE | SSE_ALU | {"cmp", "test"}:
        return transfer_data(state, program, ins)
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
    if starts[0] != 0:
        reject(1, "CONTROL_FLOW", "executable instructions precede the first exported entry")
    for start, stop in zip(starts, [*starts[1:], len(program.instructions)]):
        states = {start: State(pending_args=frozenset(program.narrow))}
        work = deque([start])
        while work:
            index = work.popleft()
            ins = program.instructions[index]
            state = transfer(states[index], program, ins, syscall_boundary, x87_return)
            if ins.opcode == "ret":
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
        if not any(program.instructions[index].opcode == "ret" for index in states):
            reject(program.instructions[start].line, "CONTROL_FLOW", "function has no reachable return")


def check_file(path, function, fixture_syscall):
    resolved = path.resolve()
    relative = resolved.relative_to(ROOT) if resolved.is_relative_to(ROOT) else resolved
    parts = relative.parts
    in_seed = parts[:2] == ("tests", "seeded-bugs")
    internal = parts[:3] == ("src", "x86_64-linux", "internal")
    if fixture_syscall and not in_seed:
        reject(1, "SYSCALL_BOUNDARY", "fixture boundary option is restricted to tests/seeded-bugs")
    if function is None and (parts[:1] in (("src",), ("ext",))) and not internal:
        function = path.stem
    narrow = {}
    variadic = set()
    external_signatures = set()
    x87_return = 0
    if function is not None or internal:
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
            variadic = {name for name, spec in project.functions.items() if spec.abi.variadic}
        except SpecError as error:
            reject(1, "SPEC_HEADER", str(error))
    program = parse(path.read_text(), narrow, set(), in_seed)
    if not in_seed or function is not None:
        program.external_signatures = external_signatures
    program.variadic.update(variadic & (set(program.entries) | program.externs))
    if function is not None and set(program.entries) != {function}:
        reject(1, "SYMBOL", f"expected exactly one export named {function}")
    verify(program, internal or fixture_syscall, x87_return)
    # NASM is the authority for operand encodings. Preprocessor directives and
    # data emission were already rejected, so it assembles exactly this subset.
    with tempfile.TemporaryDirectory(prefix="al-lint-") as directory:
        result = subprocess.run(["nasm", "-f", "elf64", "-Wall", "-Werror", "-Wno-reloc-rel-dword", "-o",
                                 str(Path(directory) / "test.o"), str(resolved)],
                                capture_output=True, text=True)
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
