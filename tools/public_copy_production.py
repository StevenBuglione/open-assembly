"""Bind frozen public-copy fixtures and retain every automatic mutation result."""

from hashlib import sha256
from pathlib import Path
import subprocess

from gate import COMPILE_FLAGS, GateError, checked, nm_symbols
from production import MUTATION_EQUIVALENCES, result_type, variants
from spec import ROOT, regular_file, sha256_file

REVIEW = Path("docs/reviews/memmove-signedness-root-review.json")
REVIEW_SHA256 = "2b97a9ee4d76248fcad9c6977f74594f6630175515672e48e8254fd27abf2a20"
FROZEN_MUTATIONS = (("copy-bulk-memmove-ordinary", (21, 22, 23)),
                    ("copy-bulk-memmove-typed-abi", (11, 12, 13)))


def validate_manifest(function, plan, probes):
    namespace = frozenset({"memcpy", "wmemcpy", "memmove"})
    required = {name for probe in probes for name in probe.case.requires}
    if plan.public != namespace or required != namespace or function not in required:
        raise GateError(f"{function}: incomplete or unexpected independent copy manifest namespace")


def generated_control(function, plan, selected, controls):
    """The independent fixture author published this named zero-stub protocol."""
    metadata = plan.generated_control
    if (type(metadata) is not tuple or len(metadata) != 2
            or type(metadata[0]) is not str or type(metadata[1]) is not tuple
            or len(metadata[1]) != 3):
        raise GateError(f"{function}: malformed named generated-stub control")
    case, rejection = metadata
    status, stdout, stderr = rejection
    if (function not in plan.public or function in controls or case not in selected
            or set(selected[case].case.requires) != {function}
            or "native" not in selected[case].case.backends
            or type(status) is not int or not 1 <= status <= 255
            or type(stdout) is not bytes or type(stderr) is not bytes
            or rejection == (selected[case].case.status, selected[case].stdout, selected[case].stderr)):
        raise GateError(f"{function}: invalid named generated-stub target, case, or rejection")
    if (function, case, rejection) != ("memmove", "copy-bulk-memmove-ordinary", (21, b"", b"")):
        raise GateError(f"{function}: no independently published named generated-stub control")
    controls[function] = selected[case], rejection


def audit_model(source, directory, log):
    records = {}
    for compiler, label in (("gcc", "candidate"), ("gcc", "glibc"), ("musl-gcc", "musl")):
        obj = directory / f"independent-model-{label}.o"
        flags = (*COMPILE_FLAGS, "-Ibuild/include/c") if label == "candidate" else COMPILE_FLAGS
        checked(log, [compiler, *flags, "-c", source, "-o", obj])
        checked(log, ["tools/elf-audit", "--test-object", obj])
        references = nm_symbols(log, obj, ["-g", "-u"])
        if references:
            raise GateError(f"{label}: independent copy model imports {references}")
        records[label] = {"object_sha256": sha256_file(obj), "undefined_symbols": references}
    return {"outcome": "pass", "source": str(source), "source_sha256": sha256_file(source),
            "objects": records}


def reviewed_equivalences(name, source, operators, plan):
    """Apply only the immutable independent review to exact observed survivors."""
    from runtime_manifest_gate import read_manifest_json

    raw = regular_file(ROOT, REVIEW, "memmove root proof review").read_bytes()
    if sha256(raw).hexdigest() != REVIEW_SHA256:
        raise GateError("memmove: stale or changed independent root review receipt")
    receipt = read_manifest_json(raw)
    if (name != "memmove" or source.as_posix() != receipt["source"]["path"]
            or sha256_file(regular_file(ROOT, source, "reviewed memmove source")) != receipt["source"]["sha256"]
            or sha256_file(regular_file(ROOT, Path(receipt["proof"]["path"]), "reviewed memmove proof"))
                != receipt["proof"]["sha256"]):
        raise GateError("memmove: source or proof differs from the independent review")
    names = [item.get("operator") for item in operators]
    if (any(type(name) is not str for name in names) or len(set(names)) != len(names)
            or len(names) != receipt["raw_total_required"]
            or {item["operator"]: item.get("source_sha256") for item in operators}
                != receipt["all_raw_operator_source_hashes"]
            or any(type(item.get("source")) is not str
                   or sha256(item["source"].encode()).hexdigest() != item["source_sha256"] for item in operators)):
        raise GateError("memmove: missing, extra, duplicate, or changed raw operator binding")
    if plan.mutations != FROZEN_MUTATIONS:
        raise GateError("memmove: independently reviewed observation inventory differs")
    expected_cases = [case for case, _ in FROZEN_MUTATIONS]
    equivalent = []
    for item in operators:
        if item["operator"] not in receipt["reviewed_equivalent_operator_source_hashes"]:
            continue
        observations = item.get("probes")
        if (item.get("killed") is not False or item.get("classification") != "survived"
                or type(observations) is not list or [probe.get("case") for probe in observations] != expected_cases
                or any(probe.get("classification") != "survived" or type(probe.get("returncode")) is not int
                       or probe.get("returncode") != 0
                       or probe.get("stdout_hex") != "" or probe.get("stderr_hex") != "" for probe in observations)):
            raise GateError(f"memmove: reviewed equivalence contradicted or unresolved for {item['operator']}")
        equivalent.append({"operator": item["operator"], "source_sha256": item["source_sha256"],
                           "review": REVIEW.as_posix(), "review_sha256": REVIEW_SHA256,
                           "proof": receipt["proof"]})
    if (len(equivalent) != 2 or len(operators) - len(equivalent) != receipt["applicable_total_permitted"]):
        raise GateError("memmove: independently reviewed applicable denominator differs")
    return equivalent


def raw_mutation_campaign(name, spec, source, original, probes, plan, directory, runtime, record):
    from runtime_manifest_gate import candidate_object, execute_native, expected
    from phase1 import build_case

    if plan.semantic_mutants:
        raise GateError(f"{name}: raw generic mutation plan must not discard supplemental operators")
    directory.mkdir()
    proof_hash, legacy = MUTATION_EQUIVALENCES.get(name, ("", {}))
    record.update(raw_policy="Every generic operator runs; only named silent semantic rejections are kills.",
                  equivalent=[], legacy_equivalence_proposals={"source_sha256": proof_hash, "operators": legacy})
    for operator, contents in variants(source, returns_value=result_type(spec) != "void" and not spec.abi.noreturn):
        work = directory / operator
        work.mkdir()
        mutant = work / f"{name}.asm"
        mutant.write_text(contents, encoding="utf-8")
        item = {"operator": operator, "source_sha256": sha256_file(mutant), "source": contents,
                "commands": [], "probes": [], "killed": False, "classification": "survived"}
        record["operators"].append(item)
        try:
            obj = candidate_object(work / f"{name}.o", mutant, name, original, item["commands"])
            item["object_sha256"] = sha256_file(obj)
            for case_name, rejection_codes in plan.mutations:
                probe = probes[case_name]
                binary, artifacts = build_case(probe.case, work / case_name, runtime, item["commands"],
                                              candidate=(name, obj))
                try:
                    observed, log = execute_native(probe, binary, work / f"{case_name}-inputs")
                except (subprocess.TimeoutExpired, GateError) as error:
                    timeout = error if isinstance(error, subprocess.TimeoutExpired) else error.__cause__
                    if not isinstance(timeout, subprocess.TimeoutExpired):
                        raise
                    item["probes"].append({"case": case_name, "binary_sha256": artifacts[binary.name],
                        "classification": "timeout", "timeout_seconds": timeout.timeout,
                        "stdout_hex": (timeout.stdout or b"").hex(), "stderr_hex": (timeout.stderr or b"").hex()})
                    item["classification"] = "unclassified"
                    continue
                outcome = "survived" if observed == expected(probe) else "rejected" if (
                    observed[0] in rejection_codes and observed[1:] == (b"", b"")) else "unclassified"
                item["probes"].append({"case": case_name, "binary_sha256": artifacts[binary.name],
                    **log, "classification": outcome, "returncode": observed[0],
                    "stdout_hex": observed[1].hex(), "stderr_hex": observed[2].hex()})
                if outcome == "rejected":
                    item.update(killed=True, classification="semantic-kill")
                    break
                if outcome == "unclassified":
                    item["classification"] = "unclassified"
        except (GateError, OSError, ValueError, subprocess.SubprocessError) as error:
            item.update(classification="harness-failure", error=str(error))
    total = len(record["operators"])
    killed = sum(item["killed"] for item in record["operators"])
    unclassified = sum(item["classification"] in {"unclassified", "harness-failure"}
                       or any(probe["classification"] in {"unclassified", "timeout"} for probe in item["probes"])
                       for item in record["operators"])
    record.update(raw_total=total, raw_killed=killed, total=total, killed=killed,
                  unclassified=unclassified, threshold_percent=90)
    if unclassified:
        raise GateError(f"{name}: raw mutation retains {unclassified} unresolved operators ({killed}/{total} semantic kills)")
    record["equivalent"] = reviewed_equivalences(name, source, record["operators"], plan)
    total -= len(record["equivalent"])
    record["total"] = total
    if not total or 100 * killed < 90 * total:
        raise GateError(f"{name}: applicable mutation killed {killed}/{total}, below 90%")
    record["outcome"] = "pass"
    print(f"PASS {name} mutation {killed}/{total} applicable; raw {killed}/{record['raw_total']} killed", flush=True)
