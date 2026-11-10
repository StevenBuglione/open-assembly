"""Audit and assemble extension packages for verification or installation."""

import shutil

from gate import GateError, checked, nm_symbols
from phase1 import NASM, build_runtime
from spec import sha256_file


def dependency_order(packages, name):
    order, seen = [], set()

    def visit(item):
        if item not in seen:
            seen.add(item)
            for dependency in packages[item].dependencies:
                visit(dependency)
            order.append(packages[item])

    visit(name)
    return order


def build_extension(directory, packages, sources, log):
    startup, core, exports, hashes = build_runtime(directory, log)
    archive = directory / "libopenasm-extension.a"
    shutil.copyfile(core, archive)
    objects = []
    for package in packages:
        for symbol, spec in package.functions.items():
            obj = directory / f"{symbol}.o"
            checked(log, [*NASM, "-o", obj, sources[symbol]])
            checked(log, ["tools/elf-audit", "--assembly-object", obj])
            definitions = nm_symbols(log, obj, ["-g", "--defined-only"])
            references = nm_symbols(log, obj, ["-g", "-u"])
            if definitions != {symbol: "T"} or symbol in exports:
                raise GateError(f"{symbol}: expected one new namespaced function export")
            if set(references) != set(spec.deps) or any(kind != "U" for kind in references.values()):
                raise GateError(f"{symbol}: object dependencies differ from the declared strong references")
            exports.update(definitions)
            objects.append(obj)
            hashes[obj.name] = sha256_file(obj)
    if any(dependency not in exports for package in packages for spec in package.functions.values()
           for dependency in spec.deps):
        raise GateError("the extension references a specified dependency with no linked implementation")
    before = checked(log, ["ar", "t", archive]).splitlines()
    if {obj.name for obj in objects} & set(before):
        raise GateError("the extension has a colliding archive member")
    checked(log, ["ar", "rD", archive, *objects])
    if checked(log, ["ar", "t", archive]).splitlines() != before + [obj.name for obj in objects]:
        raise GateError("the extension archive did not retain exact member order")
    hashes[archive.name] = sha256_file(archive)
    return startup, archive, exports, hashes
