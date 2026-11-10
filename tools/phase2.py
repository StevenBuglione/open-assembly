"""Run independent Phase 2 function gates and aggregate every result."""

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
import os
import sys

from gate import EVIDENCE, GateError, run, write_evidence
from phase2_helpers import HELPER, WRAPPERS
from production import phase2_inputs
from spec import ROOT, load_project, sha256_file

ADDITIONAL = {"atoi", "atol", "atoll", "strtol", "strtoll", "strtoul", "strtoull",
              "strtoimax", "strtoumax", "bsearch", "qsort"}
TOOLS = {"coverage": "tools/coverage", "stub": "tools/stubcheck", "mutation": "tools/mutate"}


def phase2_functions():
    project = load_project()
    return sorted(ADDITIONAL | {item.name for item in project.inventory
                                if item.kind == "functions" and item.availability == "required"
                                and item.header in {"string.h", "ctype.h"}})


def check_function(function, only):
    command = [TOOLS[only], function] if only else ["tools/gate", "--production", function]
    try:
        result = run(command, timeout=240)
    except (GateError, OSError) as error:
        return {"outcome": "fail", "error": str(error)}
    report = EVIDENCE / f"{function}.{only or 'production'}.json"
    result["outcome"] = "fail"
    if report.is_file():
        result.update(evidence=str(report), evidence_sha256=sha256_file(report))
        if result["returncode"] == 0:
            try:
                record = json.loads(report.read_text(encoding="utf-8"))
                scope = f"production-{only}" if only else "production-function"
                if (record.get("scope") == scope and record.get("outcome") == "pass"
                        and record.get("function") == function and record.get("inputs") == phase2_inputs()
                        and record.get("production_verified") is (only is None)):
                    result["outcome"] = "pass"
                else:
                    result["error"] = "function report is stale or has the wrong scope"
            except (OSError, ValueError) as error:
                result["error"] = str(error)
    return result


def check_after(function, only, prerequisites):
    for future in prerequisites:
        future.result()
    return check_function(function, only)


def check_scanner():
    report = EVIDENCE / f"{HELPER}.production.json"
    try:
        result = run(["python3", "tools/phase2_helpers.py"], timeout=240)
        result["outcome"] = "pass" if result["returncode"] == 0 and report.is_file() else "fail"
        if report.is_file():
            result.update(evidence=str(report), evidence_sha256=sha256_file(report))
        return result
    except (GateError, OSError) as error:
        return {"outcome": "fail", "error": str(error)}


def main():
    os.chdir(ROOT)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("functions", nargs="*")
    parser.add_argument("--jobs", type=int, default=min(8, len(os.sched_getaffinity(0))))
    parser.add_argument("--only", choices=TOOLS)
    args = parser.parse_args()
    available = phase2_functions()
    if args.jobs < 1 or set(args.functions) - set(available) or len(set(args.functions)) != len(args.functions):
        parser.error("supply unique Phase 2 function names and a positive job count")
    functions = args.functions or available
    specs = load_project().functions
    results = {}
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        scanner = pool.submit(check_scanner) if not args.only and set(WRAPPERS) & set(functions) else None
        by_name = {}

        def submit(function):
            if function in by_name:
                return by_name[function]
            dependencies = []
            if not args.only:
                spec = specs.get(function)
                if spec is not None:
                    dependencies.extend(submit(dep) for dep in spec.deps if dep in functions)
                if scanner and function in WRAPPERS:
                    dependencies.append(scanner)
            future = pool.submit(check_after, function, args.only, dependencies)
            by_name[function] = future
            return future

        futures = {submit(function): function for function in functions}
        if scanner:
            futures[scanner] = HELPER
        for future in as_completed(futures):
            function = futures[future]
            result = future.result()
            results[function] = result
            print(f"{result['outcome'].upper()} {function}", flush=True)
            if result["outcome"] != "pass":
                print(result.get("error") or result.get("stderr", "").strip(), file=sys.stderr, flush=True)
    helper = results.pop(HELPER, None)
    passed = sum(result["outcome"] == "pass" for result in results.values())
    success = passed == len(functions) and (helper is None or helper["outcome"] == "pass")
    evidence = {"schema_version": 1, "scope": "phase2-batch" if not args.only else f"phase2-batch-{args.only}",
                "outcome": "pass" if success else "fail", "passed": passed,
                "total": len(functions), "functions": results, "full_scope": set(functions) == set(available)}
    if helper is not None:
        evidence["shared_integer_scanner"] = helper
    report = write_evidence(f"phase2.{args.only}" if args.only else "phase2", evidence)
    print(f"Phase 2 gate results {passed}/{len(functions)}. Evidence at {report}", flush=True)
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(main())
