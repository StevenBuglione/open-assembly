"""Run independent POSIX regex tests and unmodified pinned libc-test inputs."""

import os
from pathlib import Path

from gate import GateError, checked
from phase1 import TEST_C_FLAGS
from phase4 import libc_test
from phase6 import execute_manifest_gate, phase6_inputs
from spec import ROOT, sha256_file, snapshot_inputs

SUITE = Path("tests/phase10/regex")
PUBLIC = {"regcomp", "regexec", "regerror", "regfree"}
BASIC = ("regcomp", "regexec", "regerror")
UPSTREAM = {
    "regex-backref-oob": (BASIC, "b35acb2a52feef150149066061b4e6fbceb30720d00cfbfacf943f8444630e26"),
    "regexec-nosub": (("regcomp", "regexec", "regfree"), "f758134f90e448afc462a65ad372ebc7b1b25eb71028423773828e28784fd227"),
    "regex-ere-backref": (BASIC, "bfec345d22773124d1d68f7bf2ffb3f68fc2d1223944e258f1b528a7aba7b827"),
    "regex-escaped-high-byte": (("regcomp", "regerror"), "40147c05e016eaf8f1a6e0a5ffd795c476d171741f6bf87e7f02ce06ffc5cccc"),
    "regexec-backref": (("regcomp", "regexec", "regfree"), "e6f7e762b07dd68c19d5480f0783b2ece1e0ed6853bb4813041ad2e1bb62d757"),
    "regex-negated-range": (BASIC, "5eed8d24ac32a019caba2990bd3a2411560bd5abdfc6b8494b7b92d127d92112"),
    "regex-bracket-icase": (BASIC, "733f5a7ad7b501a1840c6e4921ce0c5f269755849fb464ec37f7712e9c9e7f02"),
    "regex-backref-0": (BASIC, "d05a792876c05872fdacc0effe590f8bc727ff9d77705c7d91ab87190c1acc93"),
}
API_SHA = "c08cf85621b41c9c2b7ff33d1c60b204e506043cd20fc8ff0fa11f075e85f65f"


def inputs():
    bound = phase6_inputs()
    bound.update(snapshot_inputs(ROOT, [Path("docs/adr/0031-regular-expressions.md")]))
    return dict(sorted(bound.items()))


def external(directory, runtime, runners, checks):
    record = checks["external_conformance"] = {"outcome": "fail"}
    cases = {name: (f"regression/{name}.c", symbols) for name, (symbols, _) in UPSTREAM.items()}
    libc_test(directory / "libc-test", runtime, runners, record, cases=cases,
              c_flags=("-D_XOPEN_SOURCE=700",))
    if {name: item["source_sha256"] for name, item in record["cases"].items()} != {
            name: digest for name, (_, digest) in UPSTREAM.items()}:
        record["outcome"] = "fail"
        raise GateError("pinned regex runtime source hashes differ")
    api = Path(os.environ["OPEN_ASSEMBLY_LIBC_TEST"]) / "src/api/regex.c"
    item = checks["external_api_compile"] = {"outcome": "fail", "commands": []}
    if sha256_file(api) != API_SHA:
        raise GateError("pinned regex API source hash differs")
    obj = directory / "libc-test-regex-api.o"
    warning = ("-Wno-error=unused-function", "-Wno-error=unused-variable", "-Wno-error=unused-value")
    checked(item["commands"], ["gcc", *TEST_C_FLAGS, "-D_XOPEN_SOURCE=700", *warning,
                                "-c", api, "-o", obj])
    checked(item["commands"], ["tools/elf-audit", "--test-object", obj])
    item.update(outcome="pass", source_path="api/regex.c", source_sha256=API_SHA,
                object_sha256=sha256_file(obj))


if __name__ == "__main__":
    raise SystemExit(execute_manifest_gate(
        "phase10-regex", SUITE, PUBLIC, {SUITE / "fault.c": ("calloc",)}, (), inputs, "OA_PHASE10_HOST",
        {"limits": ["POSIX BRE and ERE, C and C.UTF-8, byte offsets.",
                    "Independent finite grammar model plus unchanged pinned libc-test regression files."]},
        external=external,
    ))
