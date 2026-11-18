"""Validate the optional source-bound model and explicit-reference proof records."""

from pathlib import Path
import re

from failure_journal import hash_json
from spec import sha256_file


def valid_hash(value):
    return type(value) is str and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def check_declared_audits(function, plan, checks, inputs):
    model = getattr(plan, "independent_model", None)
    if model is not None:
        audit = checks["candidate_build"].get("fixture_independence")
        if (type(audit) is not dict or audit.get("outcome") != "pass"
                or audit.get("source") != model.as_posix()
                or audit.get("source_sha256") != inputs.get(model.as_posix())
                or not valid_hash(audit.get("source_sha256"))
                or type(audit.get("objects")) is not dict
                or audit["objects"].keys() != {"candidate", "glibc", "musl"}):
            raise ValueError(f"{function}: missing or changed declared independent model audit")
        for item in audit["objects"].values():
            if (type(item) is not dict or item.get("outcome") != "pass"
                    or not valid_hash(item.get("object_sha256")) or item.get("undefined_symbols") != {}
                    or not valid_hash(item.get("dependency_file_sha256"))
                    or type(item.get("headers")) is not dict or not item["headers"]
                    or item.get("headers_sha256") != hash_json(item["headers"])):
                raise ValueError(f"{function}: incomplete declared model object or header audit")
            for name, digest in item["headers"].items():
                if type(name) is not str or not valid_hash(digest):
                    raise ValueError(f"{function}: invalid independent model header identity")
                path = Path(name)
                if path.is_absolute():
                    if (not path.is_relative_to("/nix/store") or path.resolve() != path
                            or not path.is_file() or sha256_file(path) != digest):
                        raise ValueError(f"{function}: changed pinned independent model header")
                elif inputs.get(name) != digest:
                    raise ValueError(f"{function}: changed captured independent model header")
    references = getattr(plan, "required_references", ())
    if references:
        from manifest_references import ASSERTIONS, MANIFEST, MANIFEST_SHA256, SOURCE, SOURCE_SHA256
        audit = checks["native_oracles"].get("required_references")
        if (function != "mbsinit" or references != (("multibyte-scalar16", "mbsinit"),)
                or plan.suite != MANIFEST.parent or inputs.get(MANIFEST.as_posix()) != MANIFEST_SHA256
                or inputs.get(SOURCE.as_posix()) != SOURCE_SHA256
                or type(audit) is not dict or audit.get("outcome") != "pass"
                or type(audit.get("bindings")) is not dict
                or audit["bindings"].keys() != {case for case, _ in references}):
            raise ValueError(f"{function}: missing or changed declared reference audit")
        cases = checks["native_oracles"].get("cases")
        if type(cases) is not dict:
            raise ValueError(f"{function}: missing declared reference observations")
        for case, symbol in references:
            item = audit["bindings"][case]
            observed = cases.get(case)
            if (type(item) is not dict or item.get("public_function") != function
                    or item.get("manifest") != MANIFEST.as_posix() or item.get("manifest_sha256") != MANIFEST_SHA256
                    or item.get("source") != SOURCE.as_posix() or item.get("source_sha256") != SOURCE_SHA256
                    or item.get("original_requires") != ["mbrtoc16", "c16rtomb"]
                    or item.get("args") != ["scalar16"] or item.get("assertions") != list(ASSERTIONS)
                    or type(item.get("builds")) is not dict or item["builds"].keys() != {"first", "second"}
                    or type(observed) is not dict or observed.get("outcome") != "pass"
                    or type(observed.get("artifacts")) is not dict
                    or observed["artifacts"].keys() != {"first", "second"}):
                raise ValueError(f"{function}: declared reference metadata or original observation changed")
            for stage, build in item["builds"].items():
                artifacts = observed["artifacts"][stage]
                if (type(build) is not dict or type(artifacts) is not dict
                        or build.get("undefined_symbol") != {symbol: "U"}
                        or build.get("defined_symbol") != {symbol: "T"}
                        or not valid_hash(build.get("test_object_sha256"))
                        or not valid_hash(build.get("binary_sha256"))
                        or build["test_object_sha256"] != artifacts.get("test-0.o")
                        or build["binary_sha256"] != artifacts.get(case)):
                    raise ValueError(f"{function}: declared strong reference differs from actual case artifacts")
