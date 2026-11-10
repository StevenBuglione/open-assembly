"""Exercise real resume and reject malformed coverage or changed artifacts."""

import argparse
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile

from campaign import BINARY_BACKEND, DOMAIN, checkpoint_name, digest, identity, partition

RUNNER = Path(__file__).with_name("campaign.py")


def invoke(*arguments, expect=0, diagnostic=None):
    result = subprocess.run([sys.executable, str(RUNNER), *map(str, arguments)],
                            capture_output=True, text=True, timeout=60)
    if result.returncode != expect or (diagnostic and diagnostic not in result.stderr):
        raise RuntimeError(f"{arguments!r}: {result.returncode}\n{result.stdout}\n{result.stderr}")


def status(path):
    return json.loads((path / "summary.json").read_text())


def native_binary(root, gate, artifacts, headers):
    from native_binary_oracle import produce, verify_wire

    for operation, start, mode, second in (("pow", 0, 2, 0xc0400000),
                                            ("atan2", 0x80000000, 1, 0x3f800000)):
        target = root / f"native-{operation}"
        invoke("prepare", target, gate, artifacts, operation, "--native-headers", headers,
               "--second", second, "--mode", mode, "--start", start, "--count", 32, "--width", 8)
        invoke("run", target, "--limit", 1)
        first = target / "checkpoints" / checkpoint_name(start, 8)
        original = first.read_bytes()
        invoke("run", target, "--workers", 2)
        result = status(target)
        assert result["oracle_backend"] == BINARY_BACKEND
        assert result["fixed_second_operand_bits"] == second and result["mode_index"] == mode
        assert result["covered_patterns"] == 32 and result["requested_interval_complete"]
        assert not result["complete_domain"] and not result["complete_binary32_axis"]
        assert first.read_bytes() == original

        for field, value in (("mode_index", mode ^ 1), ("second_bits", second ^ 1)):
            bad = json.loads(original)
            bad["report"][field] = value
            bad["report_sha256"] = identity(bad["report"])
            first.write_text(json.dumps(bad))
            invoke("run", target, "--limit", 0, expect=1, diagnostic="invalid checkpoint")
        bad = json.loads(original)
        bad["report"]["results"]["native"]["request_sha256"] = "invalid"
        bad["report_sha256"] = identity(bad["report"])
        first.write_text(json.dumps(bad))
        invoke("run", target, "--limit", 0, expect=1, diagnostic="invalid checkpoint")
        first.write_bytes(original)

        for artifact in ("native-binary", "mpfr.h", "libopenasm.a", "trans-f32"):
            path = target / "artifacts" / artifact
            contents = path.read_bytes()
            path.write_bytes(contents + b"\0")
            invoke("run", target, "--limit", 0, expect=1, diagnostic="campaign artifact changed")
            path.write_bytes(contents)
        request, response = produce(target.resolve() / "artifacts/native-binary", target,
                                    operation, start, 8, mode, second)
        verify_wire(request, response, operation, start, 8, mode, second)
        # Corrupt one interior row to check the whole wire interval.
        for offset, kind, value in ((0, "<I", start), (10, "<H", (mode ^ 1) << 10),
                                    (16, "<I", second ^ 1), (26, "<H", 0)):
            changed = bytearray(request)
            struct.pack_into(kind, changed, 32 + offset, value)
            try:
                verify_wire(changed, response, operation, start, 8, mode, second)
            except RuntimeError as error:
                assert "native binary" in str(error)
            else:
                raise AssertionError(f"accepted corrupted native binary request at offset {offset}")
        invoke("run", target, "--limit", 0)
    print("PASS native binary axes, resume, wrong mode/operand, wire and artifact locks")


def exercise(root, gate, artifacts, headers):
    target = root / "resume"
    invoke("prepare", target, gate, artifacts, "exp2", "--start", "0x3f000000",
           "--count", 32, "--width", 8)
    invoke("run", target, "--limit", 1)
    first = target / "checkpoints" / checkpoint_name(0x3f000000, 8)
    before = digest(first)
    assert status(target)["covered_patterns"] == 8
    invoke("run", target, "--workers", 2, "--limit", 2)
    assert status(target)["covered_patterns"] == 24 and digest(first) == before
    invoke("run", target, "--limit", 1)
    result = status(target)
    assert result["covered_patterns"] == 32 and result["requested_interval_complete"]
    assert not result["complete_domain"] and not result["complete_binary32_axis"]
    invoke("run", target, "--limit", 0)
    assert status(target)["new_shards_attempted"] == 0 and digest(first) == before

    original = first.read_bytes()
    bad = json.loads(original)
    bad["report"]["start"] += 1
    bad["report_sha256"] = identity(bad["report"])
    first.write_text(json.dumps(bad))
    invoke("run", target, "--limit", 0, expect=1, diagnostic="invalid checkpoint")
    first.write_bytes(original)

    overlap = first.with_name(checkpoint_name(0x3f000001, 8))
    overlap.write_bytes(original)
    invoke("run", target, "--limit", 0, expect=1, diagnostic="unexpected or overlapping")
    overlap.unlink()

    artifact = target / "artifacts" / "crt1.o"
    original = artifact.read_bytes()
    artifact.write_bytes(original + b"\0")
    invoke("run", target, "--limit", 0, expect=1, diagnostic="campaign artifact changed")
    artifact.write_bytes(original)

    source = target / "source-gate.json"
    original = source.read_bytes()
    source.write_bytes(original + b" ")
    invoke("run", target, "--limit", 0, expect=1, diagnostic="campaign source gate changed")
    source.write_bytes(original)
    invoke("run", target, "--limit", 0)

    binary = root / "binary-axis"
    invoke("prepare", binary, gate, artifacts, "pow", "--second", "0x457ff000",
           "--start", "0x3f800000", "--count", 8, "--width", 8)
    invoke("run", binary, "--limit", 1)
    result = status(binary)
    assert result["fixed_second_operand_bits"] == 0x457ff000
    assert result["requested_interval_complete"] and not result["complete_domain"]
    invoke("prepare", root / "bad-binary", gate, artifacts, "pow", "--count", 8, "--width", 8,
           expect=1, diagnostic="fixed second operand")

    if headers is None:
        return
    native = root / "native"
    invoke("prepare", native, gate, artifacts, "exp2", "--native-headers", headers,
           "--start", "0x3f000000", "--count", 32, "--width", 8)
    invoke("run", native, "--limit", 1)
    native_first = native / "checkpoints" / first.name
    original = native_first.read_bytes()
    before = digest(native_first)
    invoke("run", native, "--workers", 2, "--limit", 2)
    assert status(native)["covered_patterns"] == 24 and digest(native_first) == before
    invoke("run", native, "--workers", 2, "--limit", 1)
    result = status(native)
    assert result["oracle_backend"] == "native-mpfr-unary"
    assert result["covered_patterns"] == 32 and result["requested_interval_complete"]
    assert result["campaign_id"] != status(target)["campaign_id"]
    assert not result["complete_domain"]
    invoke("run", native, "--limit", 0)

    # Even rewriting a checkpoint's outer ID and checksum must not
    # authorize a report produced by the other oracle backend.
    transplant = json.loads(first.read_bytes())
    transplant["campaign_id"] = result["campaign_id"]
    native_first.write_text(json.dumps(transplant))
    invoke("run", native, "--limit", 0, expect=1, diagnostic="invalid checkpoint")
    native_first.write_bytes(original)
    for artifact in ("native-unary", "mpfr.h", "trans-f32"):
        path = native / "artifacts" / artifact
        original = path.read_bytes()
        path.write_bytes(original + b"\0")
        invoke("run", native, "--limit", 0, expect=1, diagnostic="campaign artifact changed")
        path.write_bytes(original)
    invoke("run", native, "--limit", 0)
    native_binary(root, gate, artifacts, headers)
    logarithm = root / "native-log2"
    invoke("prepare", logarithm, gate, artifacts, "log2", "--native-headers", headers,
           "--start", "0x3f000000", "--count", 32, "--width", 8)
    invoke("run", logarithm, "--workers", 2, "--limit", 2)
    log_first = logarithm / "checkpoints" / first.name
    original = log_first.read_bytes()
    before = digest(log_first)
    invoke("run", logarithm, "--workers", 2, "--limit", 2)
    log_status = status(logarithm)
    assert log_status["covered_patterns"] == 32 and log_status["requested_interval_complete"]
    assert log_status["campaign_id"] != result["campaign_id"] and digest(log_first) == before

    bad = json.loads(original)
    bad["report"]["operation"] = "exp2"
    bad["report_sha256"] = identity(bad["report"])
    log_first.write_text(json.dumps(bad))
    invoke("run", logarithm, "--limit", 0, expect=1, diagnostic="invalid checkpoint")
    log_first.write_bytes(original)
    invoke("run", logarithm, "--limit", 0)
    for operation, start in (("exp", "0x42b171fe"), ("log", "0x3f7ffff8"),
                             ("sin", "0x007ffff8"), ("cos", "0x7f7ffff8"),
                             ("tan", "0xbfc90fd8"), ("log10", "0x411ffff8"),
                             ("expm1", "0x80000000"), ("log1p", "0xbf7ffff8"),
                             ("asin", "0x3f7ffff8"), ("acos", "0xbf7ffff8"),
                             ("atan", "0x7f7ffff8"), ("sinh", "0x42b2d4f8"),
                             ("cosh", "0xc2b2d4f8"), ("tanh", "0x411ffff8"),
                             ("asinh", "0x007ffff8"), ("acosh", "0x3f7ffff8"),
                             ("atanh", "0xbf7ffff8"), ("erf", "0x007ffff8"),
                             ("erfc", "0x4121fff8"), ("tgamma", "0xbf7ffff8"),
                             ("lgamma", "0x3ffffff8")):
        path = root / f"native-{operation}"
        invoke("prepare", path, gate, artifacts, operation, "--native-headers", headers,
               "--mode", 2, "--start", start, "--count", 16, "--width", 8)
        invoke("run", path, "--limit", 1)
        published = next((path / "checkpoints").iterdir())
        frozen = digest(published)
        invoke("run", path, "--workers", 2, "--limit", 2)
        summary = status(path)
        assert summary["covered_patterns"] == 16 and summary["requested_interval_complete"]
        assert not summary["complete_domain"] and digest(published) == frozen
    print("PASS native resume, distinct ledger, transplant rejection, and native artifacts lock")



def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("gate", type=Path)
    parser.add_argument("artifacts", type=Path)
    parser.add_argument("--native-headers", type=Path)
    args = parser.parse_args()
    prefix = 0
    for first, count in partition(0, DOMAIN, 65536):
        assert first == prefix and count > 0
        prefix += count
    assert prefix == DOMAIN
    assert list(partition(10, 9, 4)) == [(10, 4), (14, 4), (18, 1)]
    with tempfile.TemporaryDirectory(dir="build", prefix="phase7-campaign-controls-") as temporary:
        exercise(Path(temporary), args.gate, args.artifacts, args.native_headers)
    print("PASS contiguous partitions, real resume, axis scope, altered report, overlap, and source/artifact locks")


if __name__ == "__main__":
    main()
