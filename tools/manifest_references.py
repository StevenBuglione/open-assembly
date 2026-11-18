"""Select unchanged independent observations with an explicitly audited reference."""

from pathlib import Path

from gate import GateError, nm_symbols
from spec import ROOT, sha256_file

MANIFEST = Path("tests/phase9/multibyte/manifest.toml")
MANIFEST_SHA256 = "936938c76f009d5ffb1c43c56cc8a61873d3f9dd4a2ca4ebc4bbb42ebf0454fb"
SOURCE = Path("tests/phase9/multibyte/convert.c")
SOURCE_SHA256 = "e5767d4648519d299829491ddc83ac42d2c33b6aab55400b1238c914308eddd8"
ASSERTIONS = (
    {"source": SOURCE.as_posix(), "line": 105, "observation": "queued UTF-16 decoder state is noninitial"},
    {"source": SOURCE.as_posix(), "line": 106, "observation": "pending UTF-16 encoder state is noninitial"},
    {"source": SOURCE.as_posix(), "line": 119, "observation": "completed decoder and encoder states are initial"},
)


def select_required_references(function, plan, probes):
    bindings = plan.required_references
    if type(bindings) is not tuple or not bindings:
        raise GateError("required-reference selection needs explicit tuple bindings")
    seen = set()
    for binding in bindings:
        if (type(binding) is not tuple or len(binding) != 2
                or any(type(value) is not str for value in binding)):
            raise GateError("required-reference binding is malformed")
        if binding in seen:
            raise GateError("duplicate required-reference binding")
        seen.add(binding)
        if binding[1] != function:
            raise GateError("required-reference target differs from requested function")
    if bindings != (("multibyte-scalar16", "mbsinit"),) or plan.suite != MANIFEST.parent:
        raise GateError("required-reference case or function has no independent selection contract")
    available = {probe.case.name: probe for probe in probes}
    probe = available.get("multibyte-scalar16")
    if (probe is None or probe.case.name != "multibyte-scalar16" or probe.case.sources != (SOURCE,)
            or tuple(probe.case.args) != ("scalar16",) or probe.case.requires != ("mbrtoc16", "c16rtomb")):
        raise GateError("required-reference original case metadata is missing or differs")
    if sha256_file(ROOT / MANIFEST) != MANIFEST_SHA256 or sha256_file(ROOT / SOURCE) != SOURCE_SHA256:
        raise GateError("required-reference original manifest or assertions changed")
    return {probe.case.name: probe}


def audit_required_references(function, plan, probes, directory, cases):
    selected = select_required_references(function, plan, probes.values())
    bindings = {}
    for case_name, symbol in plan.required_references:
        probe = selected[case_name]
        record = cases.get(case_name)
        if type(record) is not dict or record.get("outcome") != "pass":
            raise GateError(f"{case_name}: required-reference observation did not pass")
        builds = {}
        for stage in ("first", "second"):
            work = directory / case_name / stage
            obj, binary = work / "test-0.o", work / case_name
            artifacts = record["artifacts"][stage]
            if (sha256_file(obj) != artifacts.get(obj.name) or sha256_file(binary) != artifacts.get(binary.name)
                    or nm_symbols(record["commands"], obj, ["-g", "-u"]).get(symbol) != "U"
                    or nm_symbols(record["commands"], binary, ["-g", "--defined-only"]).get(symbol) != "T"):
                raise GateError(f"{case_name}: missing strong public test reference or linked text definition for {symbol}")
            builds[stage] = {"test_object_sha256": artifacts[obj.name], "undefined_symbol": {symbol: "U"},
                             "binary_sha256": artifacts[binary.name], "defined_symbol": {symbol: "T"}}
        bindings[case_name] = {"public_function": function, "manifest": MANIFEST.as_posix(),
            "manifest_sha256": MANIFEST_SHA256, "source": SOURCE.as_posix(), "source_sha256": SOURCE_SHA256,
            "original_requires": list(probe.case.requires), "args": list(probe.case.args),
            "selection": "The unchanged original manifest omitted this query from requires; its existing assertions are selected explicitly.",
            "assertions": list(ASSERTIONS), "builds": builds}
    return {"outcome": "pass", "bindings": bindings}
