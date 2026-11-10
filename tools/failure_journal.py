"""Persist full core function gate attempts and derive local suspension."""

from contextlib import contextmanager
from dataclasses import dataclass
from hashlib import sha256
from pathlib import Path
import fcntl
import json
import os
import re
import tempfile
from time import time_ns

from spec import IDENTIFIER, SpecError, regular_file, sha256_file


LIMIT = 3
SCOPES = {"production-function", "production-runtime-function",
          "production-runtime-manifest-function"}


class JournalError(Exception):
    pass


@dataclass(frozen=True)
class History:
    count: int
    failures: tuple[int, ...]

    @property
    def blocked(self):
        return len(self.failures) >= LIMIT


def directory(root, function):
    if not re.fullmatch(IDENTIFIER, function):
        raise JournalError(f"invalid function name {function!r}")
    path = root
    for part in ("build", "attempts", function):
        path /= part
        if path.is_symlink() or path.exists() and not path.is_dir():
            raise JournalError(f"{path}: expected a directory without symbolic links")
    return path


def is_hash(value):
    return type(value) is str and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def known_scope(value):
    return type(value) is str and value in SCOPES


def hash_json(value):
    return sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate field {key!r}")
        result[key] = value
    return result


def tool_identities(value):
    return (type(value) is dict and bool(value)
            and all(type(item) is dict and is_hash(item.get("sha256"))
                    and type(item.get("version")) is str and item["version"].strip()
                    for item in value.values()))


def source_identity(value):
    return type(value) is dict and type(value.get("path")) is str and is_hash(value.get("sha256"))


def bound_record(record):
    return (known_scope(record.get("scope")) and source_identity(record.get("source"))
            and source_identity(record.get("specification")) and tool_identities(record.get("toolchain"))
            and all(is_hash(record.get(field)) for field in
                    ("inputs_sha256", "report_sha256", "toolchain_lock_sha256")))


def load_history(root, function):
    path = directory(root, function)
    failures = []
    files = sorted(entry for entry in path.iterdir() if entry.suffix == ".json") if path.exists() else []
    for sequence, entry in enumerate(files, 1):
        if entry.name != f"{sequence:08}.json":
            raise JournalError(f"{entry}: nonconsecutive journal sequence")
        try:
            current = regular_file(root, entry.relative_to(root), "gate attempt")
            record = json.loads(current.read_text(encoding="utf-8"), object_pairs_hook=unique_object)
        except (OSError, ValueError, RecursionError, SpecError) as error:
            raise JournalError(f"{entry}: unreadable gate attempt ({error})") from error
        if (type(record) is not dict or type(record.get("schema_version")) is not int
                or record["schema_version"] != 1 or record.get("function") != function
                or type(record.get("sequence")) is not int or record["sequence"] != sequence):
            raise JournalError(f"{entry}: invalid gate attempt identity")
        kind, outcome, category = (record.get(key) for key in ("kind", "outcome", "failure_class"))
        if kind == "resume":
            if len(failures) < LIMIT or not is_hash(record.get("note_sha256")):
                raise JournalError(f"{entry}: resume without a suspended attempt window")
            failures.clear()
        elif kind == "gate" and outcome == "pass" and category is None:
            if len(failures) >= LIMIT or not bound_record(record):
                raise JournalError(f"{entry}: invalid full pass")
            failures.clear()
        elif kind == "gate" and outcome == "fail" and category in ("harness", "semantic"):
            if len(failures) >= LIMIT:
                raise JournalError(f"{entry}: gate attempt while suspended")
            if category == "semantic":
                if not bound_record(record) or not record.get("error"):
                    raise JournalError(f"{entry}: unbound semantic failure")
                failures.append(sequence)
        else:
            raise JournalError(f"{entry}: invalid gate attempt result")
    return History(len(files), tuple(failures))


@contextmanager
def lock_history(root, function):
    path = directory(root, function)
    path.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(path / ".lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX)
        yield path, load_history(root, function)
    finally:
        os.close(descriptor)


def publish(path, function, sequence, fields):
    record = {"schema_version": 1, "function": function, "sequence": sequence,
              "finished_ns": time_ns(), **fields}
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=path, prefix=".pending-",
                                         encoding="utf-8", delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(record, stream, indent=2, sort_keys=True, allow_nan=False)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.link(temporary, path / f"{sequence:08}.json")
    finally:
        if temporary is not None:
            temporary.unlink()


def note_path(function):
    return Path("docs/blocked") / f"{function}.md"


def note_identity(root, function):
    try:
        path = regular_file(root, note_path(function), "blocked investigation note")
        if path.read_text(encoding="utf-8").strip():
            return sha256_file(path)
    except (OSError, SpecError, UnicodeError):
        pass
    return None


def suspension(root, function, history):
    attempts = ", ".join(map(str, history.failures))
    note = note_path(function)
    state = f"review {note}" if note_identity(root, function) else f"write {note}"
    return f"{function}: suspended after semantic attempts {attempts}. {state} before resuming."


def resume(root, function, reason):
    if not reason.strip():
        raise JournalError("resume requires a reason")
    with lock_history(root, function) as (path, history):
        if not history.blocked:
            raise JournalError(f"{function}: no suspended attempt window")
        note = note_identity(root, function)
        if note is None:
            raise JournalError(suspension(root, function, history))
        sequence = history.count + 1
        publish(path, function, sequence, {"kind": "resume", "reason": reason.strip(), "note_sha256": note})
    return sequence


def identity(root, matches):
    if len(matches) != 1:
        return None
    relative = matches[0].relative_to(root)
    try:
        path = regular_file(root, relative, "gate attempt input")
        return {"path": relative.as_posix(), "sha256": sha256_file(path)}
    except (OSError, SpecError):
        return None


class Attempt:
    def __init__(self, root, path, function, history, sources, specifications):
        self.root = root
        self.path = path
        self.function = function
        self.history = history
        self.started_ns = time_ns()
        self.source = identity(root, sources)
        self.specification = identity(root, specifications)
        lock = identity(root, [root / "devenv.lock"])
        self.toolchain_lock = lock["sha256"] if lock else None
        self.recorded = False

    def bind_result(self, evidence, snapshot):
        passed = evidence.get("outcome") == "pass"
        if not passed and evidence.get("failure_class") != "semantic":
            return
        inputs = evidence.get("inputs")
        candidate = evidence.get("checks", {}).get("candidate_build", {})
        bound = (
            type(inputs) is dict and self.source is not None and self.specification is not None
            and all(inputs.get(entry["path"]) == entry["sha256"]
                    for entry in (self.source, self.specification))
            and candidate.get("source") == self.source["path"]
            and candidate.get("source_sha256") == self.source["sha256"]
            and candidate.get("outcome") == "pass"
            and tool_identities(evidence.get("toolchain"))
            and self.toolchain_lock is not None and inputs.get("devenv.lock") == self.toolchain_lock
        )
        if bound:
            if passed:
                return
            try:
                if evidence.get("error") and inputs == snapshot():
                    return
            except (OSError, SpecError, ValueError):
                pass
        message = "candidate, tool or input identities were unavailable or changed"
        evidence["failure_class"] = "harness"
        evidence["classification_note"] = message
        if passed:
            evidence.update(outcome="fail", production_verified=False, error=message)

    def record(self, evidence, report=None):
        scope = evidence.get("scope")
        outcome = evidence.get("outcome")
        if (outcome not in ("pass", "fail")
                or scope is not None and (not known_scope(scope) or evidence.get("function") != self.function)
                or outcome == "pass" and (not known_scope(scope) or evidence.get("production_verified") is not True)
                or outcome == "fail" and evidence.get("failure_class") not in ("harness", "semantic")):
            raise JournalError(f"{self.function}: invalid completed function gate")
        inputs = evidence.get("inputs")
        sequence = self.history.count + 1
        fields = {
            "kind": "gate", "scope": scope, "started_ns": self.started_ns, "outcome": outcome,
            "failure_class": evidence.get("failure_class"),
            "source": self.source, "specification": self.specification,
            "toolchain_lock_sha256": self.toolchain_lock,
            "toolchain": evidence.get("toolchain", {}),
            "inputs_sha256": hash_json(inputs) if type(inputs) is dict else None,
            "report_sha256": sha256_file(report) if report is not None else None,
            "error": evidence.get("error"),
        }
        if "classification_note" in evidence:
            fields["classification_note"] = evidence["classification_note"]
        publish(self.path, self.function, sequence, fields)
        self.recorded = True
        if fields["failure_class"] == "semantic":
            return History(sequence, (*self.history.failures, sequence))
        return History(sequence, () if outcome == "pass" else self.history.failures)

    def unreported(self, error):
        self.record({"outcome": "fail", "failure_class": "harness",
                     "error": f"{type(error).__name__}: {error}"})


def run_with_journal(root, function, run):
    directory(root, function)
    sources = sorted((root / "src/x86_64-linux").glob(f"*/{function}.asm"))
    specifications = sorted((root / "spec/functions").glob(f"*/{function}.toml"))
    if not sources and not specifications:
        return run(None)
    with lock_history(root, function) as (path, history):
        if history.blocked:
            raise JournalError(suspension(root, function, history))
        attempt = Attempt(root, path, function, history, sources, specifications)
        try:
            result = run(attempt)
        except (Exception, KeyboardInterrupt) as error:
            if not attempt.recorded:
                attempt.unreported(error)
            raise
        if not attempt.recorded:
            error = JournalError(f"{function}: full gate did not publish an attempt")
            attempt.unreported(error)
            raise error
        return result
