"""Run independent hosted production function gates and aggregate every result."""

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
import os
import sys

from gate import EVIDENCE, GateError, run, write_evidence
from phase2_helpers import HELPER, WRAPPERS
from phase11_copy import HELPER as COPY_HELPER
from production import SCALAR_FUNCTIONS, libfuzzer_seconds, phase2_inputs
from runtime_gate import ERRNO
from spec import ROOT, load_project, sha256_file

ADDITIONAL = {"atoi", "atol", "atoll", "strtol", "strtoll", "strtoul", "strtoull",
              "strtoimax", "strtoumax", "bsearch", "qsort"}
TOOLS = {"coverage": "tools/coverage", "stub": "tools/stubcheck", "mutation": "tools/mutate"}
# The scanner includes two input widths and a full shared mutation campaign.
SCANNER_TIMEOUT = 900


def phase2_functions():
    project = load_project()
    return sorted(ADDITIONAL | {item.name for item in project.inventory
                                if item.kind == "functions" and item.availability == "required"
                                and item.standard.startswith("C17 ") and item.header in {"string.h", "ctype.h"}})


def check_function(function, only):
    command = [TOOLS[only], function] if only else ["tools/gate", "--production", function]
    try:
        timeout = max(240, libfuzzer_seconds() + 180) if only is None else 240
        result = run(command, timeout=timeout)
    except (GateError, OSError) as error:
        return {"outcome": "fail", "error": str(error)}
    report = EVIDENCE / f"{function}.{only or 'production'}.json"
    result["outcome"] = "fail"
    if report.is_file():
        result.update(evidence=str(report), evidence_sha256=sha256_file(report))
        if result["returncode"] == 0:
            try:
                record = json.loads(report.read_text(encoding="utf-8"))
                if function == ERRNO:
                    scope = "production-runtime-function"
                else:
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


def check_private(helper, tool, timeout=240):
    report = EVIDENCE / f"{helper}.production.json"
    try:
        result = run(["python3", tool], timeout=timeout)
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
    parser.add_argument("--scalars", action="store_true", help="verify the C17 scalar arithmetic batch")
    args = parser.parse_args()
    available = sorted(SCALAR_FUNCTIONS) if args.scalars else phase2_functions()
    if args.jobs < 1 or set(args.functions) - set(available) or len(set(args.functions)) != len(args.functions):
        parser.error("supply unique function names from the selected batch and a positive job count")
    functions = args.functions or available
    specs = load_project().functions
    results = {}
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        scanner = (pool.submit(check_private, HELPER, "tools/phase2_helpers.py", SCANNER_TIMEOUT)
                   if not args.only and set(WRAPPERS) & set(functions) else None)
        errno = pool.submit(check_function, ERRNO, None) if scanner else None
        bulk_copy = (pool.submit(check_private, COPY_HELPER, "tools/phase11_copy.py")
                     if not args.only and "memcpy" in functions else None)
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
                    dependencies.extend((scanner, errno))
                if bulk_copy and function == "memcpy":
                    dependencies.append(bulk_copy)
            future = pool.submit(check_after, function, args.only, dependencies)
            by_name[function] = future
            return future

        futures = {submit(function): function for function in functions}
        if scanner:
            futures[scanner] = HELPER
            futures[errno] = ERRNO
        if bulk_copy:
            futures[bulk_copy] = COPY_HELPER
        for future in as_completed(futures):
            function = futures[future]
            result = future.result()
            results[function] = result
            print(f"{result['outcome'].upper()} {function}", flush=True)
            if result["outcome"] != "pass":
                print(result.get("error") or result.get("stderr", "").strip(), file=sys.stderr, flush=True)
    helper = results.pop(HELPER, None)
    tls = results.pop(ERRNO, None)
    copy = results.pop(COPY_HELPER, None)
    passed = sum(result["outcome"] == "pass" for result in results.values())
    success = passed == len(functions) and all(item is None or item["outcome"] == "pass"
                                               for item in (helper, tls, copy))
    name = "production-scalars" if args.scalars else "phase2"
    scope = f"{name}-batch" if not args.only else f"{name}-batch-{args.only}"
    evidence = {"schema_version": 1, "scope": scope,
                "outcome": "pass" if success else "fail", "passed": passed,
                "total": len(functions), "functions": results, "full_scope": set(functions) == set(available)}
    if helper is not None:
        evidence["shared_integer_scanner"] = helper
        evidence["runtime_tls_accessor"] = tls
    if copy is not None:
        evidence["bulk_memcpy"] = copy
    report = write_evidence(f"{name}.{args.only}" if args.only else name, evidence)
    label = "Scalar production" if args.scalars else "Phase 2"
    print(f"{label} gate results {passed}/{len(functions)}. Evidence at {report}", flush=True)
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(main())
