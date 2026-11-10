"""Build and verify the scoped Phase 9 locale and conversion interfaces."""

import argparse
from functools import partial
from pathlib import Path
import shutil
import sys
import tempfile

from gate import BUILD, GateError, identify_tools, source_policy, verify_setup, write_evidence
from phase1 import build_runtime, phase1_inputs
from phase4 import libc_test, load_probes, parse_probe
from phase6 import run_cases, run_stubs
from spec import ROOT, SpecError, load_project, snapshot_inputs

MULTIBYTE = {
    "setlocale", "localeconv", "btowc", "wctob", "mbsinit", "mbrlen", "mbrtowc", "wcrtomb",
    "mbrtoc16", "c16rtomb", "mbrtoc32", "c32rtomb",
}
BULK = {"mblen", "mbtowc", "wctomb", "mbstowcs", "wcstombs", "mbsrtowcs", "wcsrtombs"}
WIDE = {
    "wcscat", "wcschr", "wcscmp", "wcscoll", "wcscpy", "wcscspn", "wcslen", "wcsncat",
    "wcsncmp", "wcsncpy", "wcspbrk", "wcsrchr", "wcsspn", "wcsstr", "wcstok", "wcsxfrm",
    "wmemchr", "wmemcmp", "wmemcpy", "wmemmove", "wmemset",
}
LOCALE_EXTERNAL = {
    "functional-wcsstr": ("functional/wcsstr.c", ("wcsstr",)),
    "functional-wcstol": ("functional/wcstol.c", ("wcstol",)),
    "regression-wcsstr-false-negative": ("regression/wcsstr-false-negative.c", ("wcsstr",)),
    "regression-mbsrtowcs-overflow": ("regression/mbsrtowcs-overflow.c", ("mbsrtowcs",)),
    "regression-wcsncpy-read-overflow": ("regression/wcsncpy-read-overflow.c", ("wcsncpy",)),
}
STDIO = {
    "fwide", "fgetwc", "getwc", "getwchar", "fgetws", "fputwc", "putwc", "putwchar",
    "fputws", "ungetwc", "fwprintf", "wprintf", "swprintf", "vfwprintf", "vwprintf",
    "vswprintf", "fwscanf", "wscanf", "swscanf", "vfwscanf", "vwscanf", "vswscanf",
}
STDIO_EXTERNAL = {
    "functional-swprintf": ("functional/swprintf.c", ("swprintf",)),
    "functional-fwscanf": ("functional/fwscanf.c", ("fwscanf",)),
    "regression-fgetwc-buffering": ("regression/fgetwc-buffering.c", ("fgetwc",)),
}
EXTERNAL = {"libc-test": LOCALE_EXTERNAL, "stdio": STDIO_EXTERNAL}
SUITES = {
    "libc-test": ({symbol for _, symbols in LOCALE_EXTERNAL.values() for symbol in symbols},
                  ["Pinned upstream functional and regression subset with currently supported APIs."]),
    "stdio": (STDIO, ["Wide stream orientation, UTF-8 conversion and formatted I/O.",
                       "Pinned upstream wide stdio subset and independent directed controls."]),
    "multibyte": (MULTIBYTE, ["Initial C and C.UTF-8 API slice.",
                             "Valid scalar sweeps are complete for the three scalar conversion pairs.",
                             "Malformed and restartable state cases are directed.",
                             "Default state observations are single-threaded."]),
    "bulk": (BULK, ["Restartable and one-shot strings and legacy single-character conversions.",
                    "Directed input states, output capacities and malformed sequences."]),
    "worker": ({"mbrlen"}, ["Supplemental worker-local default-state and TLS reuse proof.",
                          "Single-threaded API and stub coverage is in the multibyte gate."]),
    "worker-sync": ({"mbrtowc"}, ["Supplemental combined worker TLS, condition and TSD proof."]),
    "wide": (WIDE, ["C-locale host comparisons and project C.UTF-8 collation.",
                    "Directed guard pages and 512 deterministic reference samples per case."]),
}
SCALAR_CASES = ("multibyte-scalar16", "multibyte-scalar32", "multibyte-scalar-wide")


def inputs(suite, scope):
    bound = phase1_inputs()
    paths = [Path(__file__).relative_to(ROOT), Path("tools/phase6.py"),
             Path("docs/adr/0012-c-utf8-multibyte.md"),
             *sorted(path for path in suite.iterdir() if path.is_file())]
    if scope == "libc-test":
        paths.append(Path("docs/adr/0018-wide-numeric-conversion.md"))
    if scope == "stdio":
        paths.extend(Path("docs/adr") / name for name in (
            "0021-wide-stream-orientation.md", "0023-wide-formatted-output.md",
            "0025-wide-formatted-input.md",
        ))
    bound.update(snapshot_inputs(ROOT, paths))
    return dict(sorted(bound.items()))


def execute(scope):
    name = f"phase9-{scope}"
    upstream_only = scope == "libc-test"
    suite = Path("tests/phase9") if upstream_only else Path("tests/phase9") / scope
    public, limits = SUITES[scope]
    snapshot = partial(inputs, suite, scope)
    evidence = {"schema_version": 1, "scope": name, "production_verified": False,
                "outcome": "fail", "checks": {}, "limits": limits}
    checks = evidence["checks"]
    try:
        evidence["toolchain"] = identify_tools("ar", "make", "qemu-x86_64", "musl-gcc")
        evidence["inputs"] = verify_setup(checks, False, snapshot=snapshot)
        project = load_project()
        if not public <= project.functions.keys():
            raise GateError("the public Phase 9 specifications are incomplete")
        if not upstream_only:
            wraps = {suite / "position.c": ("__al_stdio_io",)} if scope == "stdio" else {}
            parse = partial(parse_probe, suite=suite, programs=(), fault_wrappers=wraps)
            probes, controls = load_probes(suite / "manifest.toml", public, parse)
        runners = {"native": [], "qemu": [shutil.which("qemu-x86_64")],
                   "valgrind": [shutil.which("valgrind"), "--quiet", "--error-exitcode=99",
                                "--leak-check=full", "--errors-for-leak-kinds=all"]}
        workspace = BUILD / name
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as temporary:
            directory = Path(temporary).resolve().relative_to(ROOT)
            source_policy(checks, directory)
            runtime = checks["runtime_build"] = {"outcome": "fail", "commands": []}
            first = build_runtime(directory / "runtime-1", runtime["commands"])
            second = build_runtime(directory / "runtime-2", runtime["commands"])
            if first[3] != second[3]:
                raise GateError("isolated Phase 9 runtime builds differ")
            runtime.update(outcome="pass", artifacts=first[3])
            if scope in EXTERNAL:
                record = checks["external_conformance"] = {"outcome": "fail"}
                flags = ("-Wno-error=unused-parameter",)
                if scope == "stdio":
                    flags += ("-Wno-error=sign-compare",)
                common = {"regression-fgetwc-buffering": ("utf8.c",)} if scope == "stdio" else None
                libc_test(directory / "libc-test", first, runners, record, cases=EXTERNAL[scope],
                          c_flags=flags, common=common)
            if not upstream_only:
                cases = checks["cases"] = {}
                run_cases(probes, directory, first, second, runners, cases, host_macro="OA_PHASE9_HOST")
                stubs = checks["stub_controls"] = {"outcome": "fail", "symbols": {}}
                run_stubs(controls, project, directory, first, stubs)
            if scope == "multibyte":
                for case in SCALAR_CASES:
                    if set(cases[case]["runs"]) != runners.keys() or len(cases[case]["host_runs"]) != 2:
                        raise GateError(f"the full scalar case {case} omitted a backend")
                checks["scalar_domain"] = {"outcome": "pass", "observed_case_names": SCALAR_CASES,
                                           "scalar_count_per_case": 1112064,
                                           "ranges": [[0, 0xd7ff], [0xe000, 0x10ffff]]}
        if evidence["inputs"] != snapshot():
            raise GateError("inputs changed during Phase 9 verification")
        evidence["outcome"] = "pass"
        print(f"PASS {name}", flush=True)
    except (GateError, KeyError, OSError, SpecError, ValueError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence(name, evidence)
    print(f"{name} evidence {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=SUITES, default="multibyte")
    raise SystemExit(execute(parser.parse_args().suite))
