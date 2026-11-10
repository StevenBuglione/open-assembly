"""Tests for schema, generated artifacts, provenance, and queue trust boundaries."""

from collections import Counter
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from extension_abi import COMPILERS, fixture, load_baselines
from extensions import load_packages
from spec import (COMPILER_ATOMIC_ABI, PHASE0_FIXED_INPUTS, SpecError, check_comment_header,
                  comment_header, load_project, phase0_input_paths, snapshot_inputs)


STRLEN = Path("spec/functions/string/strlen.toml")


class ProjectTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        shutil.copytree(ROOT / "spec", self.root / "spec")
        (self.root / "tools").mkdir()
        for name in ("spec.py", "extensions.py", "extension_abi.py", "gen", "queue", "provenance"):
            shutil.copy(ROOT / "tools" / name, self.root / "tools" / name)

    def write(self, path, content):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        return target

    def edit(self, path, before, after):
        target = self.root / path
        original = target.read_text(encoding="utf-8")
        self.assertIn(before, original)
        target.write_text(original.replace(before, after, 1), encoding="utf-8")

    def add_function(self, name, deps=()):
        template = (self.root / STRLEN).read_text(encoding="utf-8")
        template = template.replace('name = "strlen"', f'name = "{name}"')
        template = template.replace("size_t strlen(const char *s)", f"int {name}(const char *s)")
        template = template.replace("deps = []", f"deps = {json.dumps(deps)}")
        return self.write(f"spec/functions/string/{name}.toml", template)

    def run_tool(self, name, *args, expect=0):
        run = subprocess.run(
            [sys.executable, str(self.root / "tools" / name), *args],
            cwd=self.root, text=True, capture_output=True, check=False,
        )
        self.assertEqual(expect, run.returncode, run.stdout + run.stderr)
        return run.stdout + run.stderr

    def test_catalog_covers_named_scope(self):
        project = load_project(self.root)
        c17 = [item for item in project.inventory if item.standard.startswith("C17 ")]
        self.assertEqual(29, len({item.header for item in c17}))
        self.assertEqual(
            {"functions": 501, "macros": 478, "types": 113, "generic_functions": 22,
             "constants": 14, "pragmas": 3, "families": 50},
            Counter(item.kind for item in c17),
        )
        by_item = {(item.header, item.name): item for item in project.inventory}
        self.assertEqual("required", by_item["stdalign.h", "alignof"].availability)
        self.assertEqual("macros", by_item["setjmp.h", "setjmp"].kind)
        self.assertEqual("generic_functions", by_item["stdatomic.h", "atomic_fetch_xor_explicit"].kind)
        self.assertNotEqual("required", by_item["stdint.h", "uint{N}_t"].availability)
        self.assertEqual("POSIX.1-2024 XBD <unistd.h>", by_item["unistd.h", "ssize_t"].standard)

    def test_inttypes_format_macros_match_selected_stdint(self):
        self.run_tool("gen", "--test-headers")
        fixture = ROOT / "tests/tooling/inttypes_formats.c"
        headers = self.root / "build/include/c"
        for compiler in ("gcc", "al-clang", "musl-gcc"):
            for mode in ("-fhosted", "-ffreestanding"):
                with self.subTest(compiler=compiler, mode=mode):
                    wrapper_flags = ["-Wno-unused-command-line-argument"] if compiler == "al-clang" else []
                    run = subprocess.run(
                        [compiler, "-std=c17", mode, "-fno-builtin", "-Wformat=2", "-Werror", *wrapper_flags,
                         "-fsyntax-only", "-I", str(headers), str(fixture)],
                        text=True, capture_output=True, check=False,
                    )
                    self.assertEqual(0, run.returncode, run.stdout + run.stderr)

    def test_baseline_compilers_emit_the_named_atomic_libcalls(self):
        self.run_tool("gen", "--test-headers")
        fixture = ROOT / "tests/tooling/atomic_abi_emission.c"
        headers = self.root / "build/include/c"
        for compiler in ("gcc", "al-clang"):
            for inline_only in (False, True):
                with self.subTest(compiler=compiler, inline_only=inline_only):
                    flags = ["-Wno-atomic-alignment", "-Wno-unused-command-line-argument"] if compiler == "al-clang" else []
                    if inline_only:
                        flags.append("-DLOCK_FREE_ONLY=1")
                    obj = self.root / "atomic-abi.o"
                    result = subprocess.run(
                        [compiler, "-std=c17", "-O2", "-march=x86-64", "-mno-cx16", "-ffreestanding",
                         "-fno-builtin", "-fno-pie", "-Wall", "-Wextra", "-Werror", *flags,
                         "-I", str(headers), "-c", str(fixture), "-o", str(obj)],
                        text=True, capture_output=True, check=False,
                    )
                    self.assertEqual(0, result.returncode, result.stdout + result.stderr)
                    undefined = subprocess.run(["nm", "-P", "-g", "-u", str(obj)],
                                               text=True, capture_output=True, check=True)
                    symbols = {line.split()[0] for line in undefined.stdout.splitlines()}
                    self.assertEqual(set() if inline_only else COMPILER_ATOMIC_ABI, symbols)

    def test_inventory_rejects_missing_header_duplicate_and_count_drift(self):
        path = self.root / "spec/inventory.toml"
        original = path.read_text()
        for before, after, diagnostic in (
            ('[[headers]]\nname = "assert.h"\nstandard = "C17 7.2"\ncount = 2\n'
             'macros = ["assert", "static_assert"]\n', "", "missing required header"),
            ('macros = ["assert", "static_assert"]', 'macros = ["assert", "assert"]', "duplicate value"),
            ('macros = ["assert", "static_assert"]', 'macros = ["assert"]', "does not match"),
        ):
            with self.subTest(diagnostic=diagnostic):
                path.write_text(original)
                self.edit(path, before, after)
                with self.assertRaisesRegex(SpecError, diagnostic):
                    load_project(self.root)

    def test_spec_schema_rejects_malformed_or_inconsistent_contracts(self):
        path = self.root / STRLEN
        original = path.read_text()
        for before, after, diagnostic in (
            ('name = "strlen"', 'status = "verified"\nname = "strlen"', "unknown field.*status"),
            ('name = "strlen"', 'name = "strlen"\nname = "strspn"', "overwrite a value"),
            ("as_safe = true", 'as_safe = "yes"', "expected a boolean"),
            ("strlen(const char *s)", "strlen(const char *s); int injected(void)", "expected one C function"),
            ("strlen(const char *s)", "strlen(const char *s,)", "invalid parameter"),
            ("strlen(const char *s)", "strlen(const char *s, ...)", "abi.variadic disagrees"),
            ("variadic = false", "variadic = false\nnoreturn = true", "abi.noreturn disagrees"),
            ("narrow_args = []", 'narrow_args = ["edi:s32", "dil:u8"]', "same incoming ABI register"),
            ("C17 7.24.6.3", "C17 7.21", "references do not include"),
            ("deps = []", 'deps = ["imaginary_function"]', "dependency not in inventory"),
        ):
            with self.subTest(diagnostic=diagnostic):
                path.write_text(original)
                self.edit(path, before, after)
                with self.assertRaisesRegex(SpecError, diagnostic):
                    load_project(self.root)

    def test_builtin_abi_metadata_cannot_omit_or_misclassify_narrow_args(self):
        self.edit(STRLEN, "size_t strlen(const char *s)",
                  "int strlen(float x, const char *s, unsigned short flags, signed char tag, long offset, int len)")
        with self.assertRaisesRegex(SpecError, "must include si:u16"):
            load_project(self.root)
        self.edit(STRLEN, "narrow_args = []", 'narrow_args = ["si:s16", "dl:s8", "r8d:s32"]')
        with self.assertRaisesRegex(SpecError, "must include si:u16"):
            load_project(self.root)
        self.edit(STRLEN, '"si:s16"', '"si:u16"')
        load_project(self.root)
        self.edit(STRLEN, '"si:u16"', '"edi:s32", "si:u16"')
        with self.assertRaisesRegex(SpecError, "full-width argument"):
            load_project(self.root)

    def test_opaque_abi_types_leave_unresolved_registers_to_explicit_metadata(self):
        self.edit(STRLEN, "size_t strlen(const char *s)", "int strlen(int len, opaque_t value, char flags)")
        with self.assertRaisesRegex(SpecError, "must include edi:s32"):
            load_project(self.root)
        self.edit(STRLEN, "narrow_args = []", 'narrow_args = ["edi:s32", "dl:u8"]')
        load_project(self.root)

    def test_duplicate_function_and_dependency_cycle(self):
        copy = self.write("spec/functions/z/strlen.toml", (self.root / STRLEN).read_text())
        with self.assertRaisesRegex(SpecError, "duplicate function name"):
            load_project(self.root)
        copy.unlink()
        self.add_function("strncat", ("strlen",))
        self.edit(STRLEN, "deps = []", 'deps = ["strncat"]')
        with self.assertRaisesRegex(SpecError, "cycle: strlen -> strncat -> strlen"):
            load_project(self.root)

    def test_generation_is_reproducible_and_check_does_not_repair(self):
        self.run_tool("gen")
        outputs = [self.root / item for item in ("include/asm/string.inc", "build/include/c/string.h", "docs/api-index.md")]
        first = [path.read_bytes() for path in outputs]
        self.run_tool("gen")
        self.assertEqual(first, [path.read_bytes() for path in outputs])
        self.run_tool("gen", "--check")
        outputs[0].write_bytes(first[0] + b"; stale\n")
        self.run_tool("gen", "--test-headers")
        self.assertIn("stale output: include/asm/string.inc", self.run_tool("gen", "--check", expect=1))
        self.assertEqual(first[0] + b"; stale\n", outputs[0].read_bytes())
        self.run_tool("gen")
        self.assertEqual(first, [path.read_bytes() for path in outputs])
        outputs[1].unlink()
        self.run_tool("gen", "--check", "--tracked-only")
        self.assertIn("missing output: build/include/c/string.h", self.run_tool("gen", "--check", expect=1))

    def test_obsolete_output_detected_without_deleting_unrelated_file(self):
        self.run_tool("gen")
        source = self.write("include/asm/retired.inc", "; written by a human\n")
        self.assertIn("unexpected output", self.run_tool("gen", "--check", expect=1))
        self.assertIn("refusing to delete non-generated", self.run_tool("gen", expect=1))
        self.assertEqual("; written by a human\n", source.read_text())

    def test_stable_extension_declaration_and_layout_controls(self):
        package_path = "ext/abi_control/package.toml"
        self.write(package_path, '''schema_version = 1
name = "abi_control"
stability = "stable"
dependencies = []
oracle = "reference:abi-control"
''')
        spec_path = "ext/abi_control/spec/functions/abi_control_size.toml"
        prototype = "size_t abi_control_size(const struct abi_control_record *item)"
        self.write(spec_path, f'''name = "abi_control_size"
header = "abi_control.h"
prototype = "{prototype}"
standard = ["Extension ABI abi_control"]
deps = []
errno = []
mt_safe = true
as_safe = true
oracles = ["reference:abi-control"]
provenance = "original"
semantics = ["Return the record extent."]

[abi]
narrow_args = []
variadic = false
''')
        baseline_path = "tests/oracle/abi_control/extension-abi.toml"
        baseline_file = self.write(baseline_path, f'''schema_version = 1
target = "x86_64-linux-sysv"
package = "abi_control"

[[function]]
name = "abi_control_size"
prototype = "{prototype}"
narrow_args = []
variadic = false
noreturn = false

[[layout]]
name = "abi_control_record"
size = 12
align = 4
member = [
  {{name = "flags", type = "uint32_t", offset = 0}},
  {{name = "payload", type = "uint8_t", count = 8, offset = 4}},
]
''')
        self.run_tool("gen", "--test-headers")
        project = load_project(self.root)
        packages = load_packages(project)
        baseline = load_baselines(self.root, packages)["abi_control"]
        source = self.write("abi.c", fixture("abi_control.h", baseline))
        relative_header = "build/include/c/abi_control.h"
        header = self.root / relative_header
        original_header = header.read_text()
        for before, after, diagnostic in (
                ("", "", ""),
                (prototype, prototype.replace("size_t", "long"), "prototype abi_control_size"),
                ("uint32_t flags", "uint64_t flags", "offset abi_control_record.payload"),
                ("uint32_t flags", "int32_t flags", "type abi_control_record.flags"),
                ("payload[8]", "payload[9]", "type abi_control_record.payload")):
            self.write(relative_header, original_header)
            if diagnostic:
                self.edit(relative_header, before, after)
            for compiler in COMPILERS:
                with self.subTest(compiler=compiler, diagnostic=diagnostic):
                    result = subprocess.run(
                        [compiler, "-std=c17", "-ffreestanding", "-fno-builtin", "-Wall", "-Werror",
                         "-I", str(header.parent), "-c", str(source), "-o", str(self.root / "abi.o")],
                        text=True, capture_output=True, check=False,
                    )
                    if diagnostic:
                        self.assertNotEqual(result.returncode, 0)
                        self.assertIn(diagnostic, result.stderr)
                    else:
                        self.assertEqual(result.returncode, 0, result.stderr)

        self.edit(spec_path, prototype, prototype.replace("size_t", "long"))
        self.assertIn("stable declaration changed for abi_control_size",
                      self.run_tool("gen", "--test-headers", expect=1))
        self.edit(spec_path, prototype.replace("size_t", "long"), prototype)
        self.edit(package_path, '"stable"', '"experimental"')
        self.assertIn("must remain a stable package", self.run_tool("gen", "--test-headers", expect=1))
        self.edit(package_path, '"experimental"', '"stable"')
        baseline_file.unlink()
        self.assertIn("missing protected baseline for abi_control", self.run_tool("gen", "--test-headers", expect=1))

    def test_comment_header_is_exact_and_only_production_source_counts(self):
        spec = load_project(self.root).functions["strlen"]
        header = self.run_tool("gen", "--comment-header", "strlen")
        self.assertEqual(comment_header(spec), header)
        source = self.write("src/x86_64-linux/string/strlen.asm", header + "; implementation would follow\n")
        check_comment_header(source, spec)
        self.assertIn("1 production source header", self.run_tool("provenance", "--check"))
        self.assertIn("strlen: implemented", self.run_tool("queue", "status"))
        source.write_text(header.replace("provenance: original", "provenance: unknown"))
        self.assertIn("stale generated comment header", self.run_tool("provenance", "--check", expect=1))

    def test_provenance_rejects_misrepresented_sources_and_requires_notice(self):
        record = (
            'provenance = { origin = "musl", url = "https://github.com/bminor/glibc", '
            f'revision = "{"a" * 40}", upstream_path = "src/string/strlen.c", '
            'license = "MIT", notice = "spec/provenance/strlen.txt" }'
        )
        self.edit(STRLEN, 'provenance = "original"', record)
        self.assertIn("allowed musl upstream", self.run_tool("provenance", expect=1))
        self.edit(STRLEN, "https://github.com/bminor/glibc", "https://git.musl-libc.org/cgit/musl")
        self.edit(STRLEN, 'license = "MIT"', 'license = "LGPL-2.1-only"')
        self.assertIn("permissive per-file license", self.run_tool("provenance", expect=1))
        self.edit(STRLEN, 'license = "LGPL-2.1-only"', 'license = "MIT"')
        self.assertIn("missing regular file: spec/provenance/strlen.txt", self.run_tool("provenance", expect=1))

    def fixture_evidence(self):
        paths = (*PHASE0_FIXED_INPUTS, "tools/gate.py", "tests/fixtures/positive.asm", "tests/unit/strlen.c")
        for path in paths:
            self.write(path, "placeholder bytes used only for the queue parser test\n")
        return {
            "schema_version": 1, "scope": "phase0-fixture", "function": "strlen",
            "outcome": "pass", "production_verified": False,
            "inputs": snapshot_inputs(self.root, phase0_input_paths(self.root)),
            "toolchain": {"nasm": {"version": "test-only identity", "sha256": "a" * 64}},
            "checks": {"semantic": {"outcome": "pass"}, "coverage": {"outcome": "pending"}},
        }

    def phase0_queue_specs(self):
        # Model the Phase 0 fixture queue in isolation from newer runtime specs.
        for path in (self.root / "spec/functions").rglob("*.toml"):
            if path != self.root / STRLEN:
                path.unlink()
        self.write("spec/deviations.toml", "schema_version = 1\ndeviations = []\n")

    def test_evidence_never_unlocks_dependencies_in_phase0(self):
        self.phase0_queue_specs()
        self.add_function("strncat", ("strlen",))
        self.assertEqual("strlen\n", self.run_tool("queue", "next"))
        good = self.fixture_evidence()
        for record, message in (
            (json.dumps(good), "fixture pass (1 pending checks; fixture only)"),
            (json.dumps({**good, "scope": "phase0"}), "out of scope"),
            (json.dumps({**good, "scope": "production-function", "production_verified": True}),
             "unsupported production evidence"),
            ('{"scope": "phase0-fixture", "scope": "production-function"}', "duplicate JSON key"),
            (json.dumps({**good, "inputs": {"../outside": "a" * 64, **good["inputs"]}}),
             "expected a normalized repository-relative path"),
            (json.dumps({**good, "production_verified": True}), "malformed fixture identity"),
        ):
            with self.subTest(message=message):
                self.write("build/evidence/strlen.json", record)
                self.assertIn(message, self.run_tool("queue", "status", "strlen"))
                self.assertIn("unmet dependencies: strlen", self.run_tool("queue", "status", "strncat"))
                self.assertEqual("strlen\n", self.run_tool("queue", "next"))

        self.write("build/evidence/strlen.json", json.dumps(good))
        extra = self.write("tests/unit/another.c", "additional input")
        self.assertIn("stale fixture evidence (input path set changed)", self.run_tool("queue", "status"))
        extra.unlink()
        self.write("tests/unit/strlen.c", "changed bytes")
        self.assertIn("stale fixture evidence (changed: tests/unit/strlen.c)", self.run_tool("queue", "status"))
        spec = load_project(self.root).functions["strlen"]
        self.write("src/x86_64-linux/string/strlen.asm", comment_header(spec))
        self.assertIn("no eligible specified function", self.run_tool("queue", "next", expect=1))

    def test_dependency_on_inventoried_but_unspecified_function_is_pending(self):
        self.phase0_queue_specs()
        self.edit(STRLEN, "deps = []", 'deps = ["strncat"]')
        self.assertIn("strncat: todo; specification pending", self.run_tool("queue", "status", "strncat"))
        self.assertIn("no eligible specified function", self.run_tool("queue", "next", expect=1))


if __name__ == "__main__":
    unittest.main()
