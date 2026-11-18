"""Compile an independent model with current headers and require no imports."""

from pathlib import Path
import shlex

from failure_journal import hash_json
from gate import COMPILE_FLAGS, GateError, checked, nm_symbols
from spec import ROOT, regular_file, sha256_file


def captured_file(path, inputs):
    relative = path.relative_to(ROOT)
    expected = inputs.get(relative.as_posix())
    actual = sha256_file(regular_file(ROOT, relative, "independent model input"))
    if expected != actual:
        raise GateError(f"{relative}: independent model input is missing or changed since capture")
    return relative.as_posix(), actual


def model_headers(dependencies, source, inputs):
    target, separator, raw = dependencies.read_text().replace("\\\n", "").partition(":")
    if not target or not separator:
        raise GateError("independent model dependency file is malformed")
    files = [Path(value) for value in shlex.split(raw)]
    if not files:
        raise GateError("independent model dependency file is empty")
    headers = {}
    saw_source = False
    for path in files:
        path = path.resolve() if path.is_absolute() else (ROOT / path).resolve()
        if path == source:
            captured_file(path, inputs)
            saw_source = True
            continue
        if path.is_relative_to(ROOT):
            name, value = captured_file(path, inputs)
        elif path.is_relative_to("/nix/store"):
            if not path.is_file():
                raise GateError(f"{path}: independent model toolchain header is absent")
            name, value = path.as_posix(), sha256_file(path)
        else:
            raise GateError(f"{path}: independent model header is outside captured inputs and pinned toolchain")
        if name in headers:
            raise GateError(f"{name}: duplicate independent model dependency")
        headers[name] = value
    if not saw_source or not headers:
        raise GateError("independent model dependencies omit source or headers")
    return dict(sorted(headers.items()))


def audit_model(source, directory, log, inputs):
    if not isinstance(source, Path) or not source.is_relative_to("tests") or source.suffix != ".c":
        raise GateError("independent model must be a captured C test source")
    actual = regular_file(ROOT, source, "independent model source")
    name, source_hash = captured_file(actual, inputs)
    records = {}
    for compiler, label in (("gcc", "candidate"), ("gcc", "glibc"), ("musl-gcc", "musl")):
        obj = directory / f"independent-model-{label}.o"
        dependencies = directory / f"independent-model-{label}.d"
        flags = (*COMPILE_FLAGS, "-Ibuild/include/c") if label == "candidate" else COMPILE_FLAGS
        checked(log, [compiler, *flags, "-MD", "-MF", dependencies, "-c", source, "-o", obj])
        checked(log, ["tools/elf-audit", "--test-object", obj])
        undefined = nm_symbols(log, obj, ["-g", "-u"])
        if undefined:
            raise GateError(f"{label}: independent model imports {undefined}")
        headers = model_headers(dependencies, actual, inputs)
        records[label] = {"outcome": "pass", "object_sha256": sha256_file(obj), "undefined_symbols": undefined,
                          "headers": headers, "headers_sha256": hash_json(headers),
                          "dependency_file_sha256": sha256_file(dependencies)}
    if captured_file(actual, inputs) != (name, source_hash):
        raise GateError("independent model source changed while compiling")
    return {"outcome": "pass", "source": name, "source_sha256": source_hash, "objects": records}
