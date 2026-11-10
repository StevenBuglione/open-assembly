"""Verify extension scaffold confinement, namespace and dependency failures."""

from argparse import Namespace
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from extensions import create_function, create_package, extension_sources, load_packages
from spec import Project, SpecError, comment_header


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


if __name__ == "__main__":
    unittest.main()
