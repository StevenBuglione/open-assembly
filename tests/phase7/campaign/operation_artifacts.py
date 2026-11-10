"""Build and compare static, single-operation binary32 campaign probes."""

from hashlib import sha256
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools"))
from gate import GateError, checked, nm_symbols
from phase1 import RUNTIME_LINK, TEST_C_FLAGS
from phase7_exact import require_symbols
from phase7_transcendental import OPERATIONS
from spec import ROOT, regular_file, relative_path, sha256_file

SOURCE = Path(__file__).resolve().relative_to(ROOT).with_name("operation_probe.c")
BINARY_OPERATIONS = {"pow", "atan2"}


def build_probe(directory, runtime, operation, log):
    """Link only the selected typed operation and its archive dependencies."""
    ordinal = OPERATIONS.index(operation)
    symbol = operation + "f"
    startup, archive, exports, _ = runtime
    if exports.get(symbol) != "T":
        raise GateError(f"the runtime archive lacks {symbol}")
    directory.mkdir(parents=True)
    obj, binary, mapping = (directory / name for name in ("trans-f32.o", "trans-f32", "link.map"))
    defines = (f"-DTEST_OPERATION_ID={ordinal}", f"-DTEST_OPERATION_SYMBOL={symbol}",
               f"-DTEST_OPERATION_BINARY={int(operation in BINARY_OPERATIONS)}")
    checked(log, ["gcc", *TEST_C_FLAGS, *defines, "-c", SOURCE, "-o", obj])
    checked(log, ["tools/elf-audit", "--test-object", obj])
    imports = nm_symbols(log, obj, ["-g", "--undefined-only"])
    if imports != {name: "U" for name in (symbol, "__errno_location", "read", "write")}:
        raise GateError(f"unexpected imports for {symbol}: {imports}")
    checked(log, [*RUNTIME_LINK, f"-Map={mapping}", "--cref", "-o", binary, startup, obj, archive])
    checked(log, ["tools/elf-audit", binary])
    require_symbols(log, binary, ["--defined-only"], {"_start", "main", symbol}, "T")
    artifacts = {"probe": binary, "object": obj, "map": mapping, "archive": archive, "startup": startup}
    result = {"operation": operation, "wire_id": ordinal, "imports": sorted(imports)}
    for name, path in artifacts.items():
        result[name] = str(path)
        result[f"{name}_sha256"] = sha256_file(path)
    return result


def compare_probes(origin, current, *, origin_oracle, current_oracle):
    """Describe equality of two audited builds without crediting campaign records."""
    old, new = (regular_file(ROOT, relative_path(item["probe"], "operation probe"), "operation probe").read_bytes()
                for item in (origin, current))
    if (sha256(old).hexdigest() != origin["probe_sha256"] or
            sha256(new).hexdigest() != current["probe_sha256"]):
        raise GateError("probe bytes differ from their audited identity")
    if (origin["operation"], origin["wire_id"]) != (current["operation"], current["wire_id"]):
        raise GateError("operation identities differ")
    if origin_oracle != current_oracle:
        raise GateError("oracle identities differ")
    if old != new:
        raise GateError("probe ELF bytes differ")
    return {"scope": "operation probe byte equality", "outcome": "pass", "origin": origin,
            "current": current, "oracle": origin_oracle, "new_observations": 0, "release_credit": 0}
