"""Verify extension scaffold and production tooling controls."""

from argparse import Namespace
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from extensions import create_function, create_package, extension_sources, load_packages
from gate import GateError
from production import MUTATION_EQUIVALENCES
import runtime_manifest_gate
from spec import Project, SpecError, comment_header, sha256_file


class ExtensionScaffold(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.project = Project(self.root, {}, (), ())

    def package(self, name="word_math", depends=(), oracle="reference:unsigned-minimum"):
        with redirect_stdout(StringIO()):
            create_package(self.project, Namespace(name=name, depends=list(depends), oracle=oracle,
                                                    stability="experimental"))

    def function(self, depends=(), prototype=None):
        prototype = prototype or "unsigned int word_math_clamp_u32(unsigned int value, unsigned int ceiling)"
        with redirect_stdout(StringIO()):
            return create_function(self.project, Namespace(
                package="word_math", name="clamp_u32", depends=list(depends), prototype=prototype,
                semantics=["Return the unsigned minimum."], mt_safe=True, as_safe=True,
                narrow_arg=["edi:u32", "esi:u32"],
            ))

    def test_valid_pending_package(self):
        self.package()
        self.function()
        package = load_packages(self.project)["word_math"]
        spec = package.functions["word_math_clamp_u32"]
        self.assertIn("; narrow_args: edi:u32, esi:u32\n", comment_header(spec))
        self.assertEqual(package.source(spec.name).as_posix(), "ext/word_math/src/x86_64-linux/word_math_clamp_u32.asm")
        self.assertEqual(extension_sources(self.project, {package.name: package}), {})
        self.assertTrue((self.root / package.tests / "manifest.toml").is_file())

    def test_invalid_package_names_or_oracles(self):
        for name in ("../escape", "/absolute", "x/y", "."):
            with self.subTest(name=name), self.assertRaises(SpecError):
                self.package(name)
        with self.assertRaisesRegex(SpecError, "package oracle"):
            self.package(oracle="diff:glibc")
        self.assertFalse((self.root / "ext").exists())

    def test_symlink_ancestor(self):
        other = self.root / "other"
        other.mkdir()
        (self.root / "ext").symlink_to(other, target_is_directory=True)
        with self.assertRaisesRegex(SpecError, "symbolic links"):
            self.package()
        self.assertEqual(list(other.iterdir()), [])

    def test_dependency_errors(self):
        with self.assertRaisesRegex(SpecError, "unknown package dependencies"):
            self.package(depends=("missing",))
        self.package()
        with self.assertRaisesRegex(SpecError, "undeclared function dependencies"):
            self.function(depends=("missing",))
        self.assertEqual(load_packages(self.project)["word_math"].functions, {})

    def test_package_cycle(self):
        self.package("first")
        self.package("second", depends=("first",))
        path = self.root / "ext/first/package.toml"
        path.write_text(path.read_text().replace("dependencies = []", 'dependencies = ["second"]'))
        with self.assertRaisesRegex(SpecError, "cycle"):
            load_packages(self.project)

    def test_no_overwrite(self):
        self.package()
        with self.assertRaisesRegex(SpecError, "already exists"):
            self.package()
        self.function()
        path = self.root / "ext/word_math/spec/functions/word_math_clamp_u32.toml"
        original = path.read_bytes()
        with self.assertRaisesRegex(SpecError, "already exists"):
            self.function()
        self.assertEqual(path.read_bytes(), original)

    def test_invalid_prototype_does_not_publish(self):
        self.package()
        with self.assertRaises(SpecError):
            self.function(prototype="int wrong(void)")
        directory = self.root / "ext/word_math/spec/functions"
        self.assertEqual(list(directory.iterdir()), [])

    def test_architecture_path_is_checked(self):
        self.package()
        self.function()
        path = self.root / "ext/word_math/word_math_clamp_u32.asm"
        path.touch()
        with self.assertRaisesRegex(SpecError, "architecture path"):
            extension_sources(self.project, load_packages(self.project))


class ExtensionMutationProofs(unittest.TestCase):
    def setUp(self):
        self.root = Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.name = "mutation_control"
        self.source = self.root / f"{self.name}.asm"
        # Two generated variants per branch, and two return variants.
        branches = [f"    jb .edge_{index}\n" for index in range(65)]
        self.source.write_text("".join([*branches, "    ret\n"]), encoding="utf-8")
        self.proofs = {f"comparison-signedness-{line}": "Synthetic equivalent operator."
                       for line in range(1, 17)}
        self.enterContext(patch.dict(MUTATION_EQUIVALENCES,
                                     {self.name: (sha256_file(self.source), self.proofs)}))
        self.object = self.root / "control.o"
        self.object.write_bytes(b"synthetic object")
        self.binary = self.root / "control"
        self.record = {"outcome": "fail", "operators": []}
        self.distinct = ([f"invert-branch-{line}" for line in range(1, 66)]
                         + [f"comparison-signedness-{line}" for line in range(17, 66)]
                         + ["return-plus-one", "return-minus-one"])

    def evaluate(self, killed):
        spec = SimpleNamespace(prototype="int mutation_control(void)", abi=SimpleNamespace(noreturn=False))
        case = SimpleNamespace(status=0)
        probe = SimpleNamespace(case=case, stdout=b"", stderr=b"", wraps=())
        plan = SimpleNamespace(mutations=(("probe", (42,)),))

        def observe(_probe, _binary, directory):
            status = 42 if directory.parent.name in killed else 0
            return (status, b"", b""), {}

        with patch.multiple(runtime_manifest_gate, candidate_object=lambda *_: self.object,
                            build_case=lambda *_, **__: (self.binary, {self.binary.name: "synthetic"}),
                            execute_native=observe), redirect_stdout(StringIO()):
            runtime_manifest_gate.mutate_function(
                self.name, spec, self.source, self.object, {"probe": probe}, plan, self.root / "mutation",
                None, self.record, run_equivalent=True)

    def test_changed_source_rejects_equivalence(self):
        with self.source.open("a", encoding="utf-8") as stream:
            stream.write("\n")
        with self.assertRaisesRegex(GateError, "source changed"):
            self.evaluate(set())
        self.assertEqual(self.record["operators"], [])

    def test_score_just_below_threshold(self):
        with self.assertRaisesRegex(GateError, "104/116, below 90%"):
            self.evaluate(set(self.distinct[:104]))
        self.assertEqual((self.record["raw_killed"], self.record["raw_total"]), (104, 132))
        self.assertEqual(self.record["outcome"], "fail")

    def test_score_just_above_threshold_retains_raw_results(self):
        self.evaluate(set(self.distinct[:105]))
        self.assertEqual((self.record["killed"], self.record["total"]), (105, 116))
        self.assertEqual((self.record["raw_killed"], self.record["raw_total"]), (105, 132))
        self.assertEqual({item["operator"] for item in self.record["equivalent"]}, set(self.proofs))
        self.assertEqual(len(self.record["operators"]), 132)
        self.assertEqual(self.record["outcome"], "pass")

    def test_observed_equivalence_contradiction_fails(self):
        with self.assertRaisesRegex(GateError, "equivalence contradicted by comparison-signedness-1"):
            self.evaluate(set(self.distinct[:105]) | {"comparison-signedness-1"})
        self.assertEqual((self.record["raw_killed"], self.record["raw_total"]), (106, 132))
        self.assertEqual(self.record["outcome"], "fail")


if __name__ == "__main__":
    unittest.main()
