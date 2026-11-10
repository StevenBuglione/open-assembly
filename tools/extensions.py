"""Read independent extension package metadata and scaffold valid contracts."""

from dataclasses import dataclass
import argparse
import json
from pathlib import Path
import re
import sys
from tempfile import NamedTemporaryFile

from spec import (ROOT, SpecError, fail, keys, load_function, load_project,
                  matching, read_toml, regular_file, relative_path, string_list, version_one)

NAME = r"[a-z][a-z0-9_]*"
ORACLE = r"(?:reference|suite):[A-Za-z0-9][A-Za-z0-9_.+/-]*"
STABILITY = r"experimental|stable"


@dataclass(frozen=True)
class Package:
    name: str
    stability: str
    dependencies: tuple
    oracle: str
    functions: dict

    @property
    def path(self):
        return Path("ext") / self.name

    @property
    def header(self):
        return self.name + ".h"

    @property
    def tests(self):
        return Path("tests/ext") / self.name

    def source(self, symbol):
        return self.path / "src/x86_64-linux" / f"{symbol}.asm"


def confined(root, relative):
    current = root
    for part in relative_path(str(relative), "extension path").parts:
        current /= part
        if current.is_symlink():
            fail(relative, "symbolic links are unsupported")
    return current


def load_packages(project):
    root = project.root
    directory = confined(root, Path("ext"))
    if not directory.exists():
        return {}
    if not directory.is_dir():
        fail(directory, "expected a package directory")
    packages, symbols = {}, set(project.functions)
    runtime_headers = {item.header for item in project.inventory}
    for path in sorted(directory.iterdir()):
        if not path.is_dir() or path.is_symlink():
            fail(path, "expected a regular extension package directory")
        name = matching(path.name, NAME, path)
        if name + ".h" in runtime_headers:
            fail(path, "extension header collides with a runtime header")
        metadata = regular_file(root, path.relative_to(root) / "package.toml", path)
        raw = read_toml(metadata)
        keys(raw, {"schema_version", "name", "stability", "dependencies", "oracle"}, metadata)
        version_one(raw["schema_version"], metadata)
        if raw["name"] != name:
            fail(metadata, "package name must match the directory")
        stability = matching(raw["stability"], STABILITY, metadata)
        dependencies = string_list(raw["dependencies"], NAME, metadata)
        oracle = matching(raw["oracle"], ORACLE, metadata)
        spec_dir = confined(root, path.relative_to(root) / "spec/functions")
        functions = {}
        for spec_file in sorted(spec_dir.glob("*.toml")):
            spec = load_function(regular_file(root, spec_file.relative_to(root), path), root)
            if (not re.fullmatch(name + r"_[a-z][a-z0-9_]*", spec.name)
                    or spec_file.stem != spec.name or spec.header != name + ".h"
                    or spec.standard != (f"Extension ABI {name}",) or spec.oracles != (oracle,)):
                fail(spec_file, "function name, header, standard and oracle must match the package")
            if spec.name in symbols:
                fail(spec_file, f"duplicate function name: {spec.name}")
            symbols.add(spec.name)
            functions[spec.name] = spec
        packages[name] = Package(name, stability, dependencies, oracle, functions)

    def check_graph(graph):
        visited, active = set(), []

        def visit(item):
            if item in active:
                fail("extension dependencies", "cycle: " + " -> ".join((*active, item)))
            if item in visited:
                return
            active.append(item)
            for dep in graph[item]:
                if dep in graph:
                    visit(dep)
            active.pop()
            visited.add(item)

        for item in graph:
            visit(item)

    check_graph({name: package.dependencies for name, package in packages.items()})
    function_graph = {}
    for package in packages.values():
        allowed = set(project.functions) | package.functions.keys()
        for dep in package.dependencies:
            if dep not in packages:
                fail(package.path, f"unknown package dependency: {dep}")
            allowed.update(packages[dep].functions)
        for spec in package.functions.values():
            if unknown := set(spec.deps) - allowed:
                fail(spec.path, "undeclared function dependencies: " + ", ".join(sorted(unknown)))
            function_graph[spec.name] = spec.deps
    check_graph(function_graph)
    return packages


def extension_functions(packages):
    return {symbol: spec for package in packages.values() for symbol, spec in package.functions.items()}


def extension_sources(project, packages):
    expected = {package.source(symbol): symbol for package in packages.values() for symbol in package.functions}
    sources = {}
    for path in sorted((project.root / "ext").rglob("*.asm")):
        relative = path.relative_to(project.root)
        if relative not in expected:
            fail(relative, "extension source must match a declared function's architecture path")
        sources[expected[relative]] = regular_file(project.root, relative, "extension source")
    return sources


def create_package(project, args):
    name = matching(args.name, NAME, "package name")
    oracle = matching(args.oracle, ORACLE, "package oracle")
    packages = load_packages(project)
    dependencies = string_list(args.depends, NAME, "package dependencies")
    if unknown := set(dependencies) - packages.keys():
        fail(name, "unknown package dependencies: " + ", ".join(sorted(unknown)))
    if name + ".h" in {item.header for item in project.inventory}:
        fail(name, "extension header collides with a runtime header")
    package = Package(name, args.stability, dependencies, oracle, {})
    destination, tests = (confined(project.root, path) for path in (package.path, package.tests))
    for path in (destination, tests):
        if path.exists():
            fail(path, "scaffold target already exists")
    destination.parent.mkdir(parents=True, exist_ok=True)
    tests.parent.mkdir(parents=True, exist_ok=True)
    destination.mkdir()
    metadata = destination / "package.toml"
    created_tests = False
    try:
        tests.mkdir()
        created_tests = True
        with metadata.open("x", encoding="utf-8") as file:
            file.write(
                f"schema_version = 1\nname = {json.dumps(name)}\nstability = {json.dumps(args.stability)}\n"
                f"dependencies = {json.dumps(dependencies)}\noracle = {json.dumps(oracle)}\n"
            )
        with (tests / "manifest.toml").open("x", encoding="utf-8") as file:
            file.write("schema = 1\ncase = []\nstub = []\n")
    except OSError:
        metadata.unlink(missing_ok=True)
        destination.rmdir()
        if created_tests:
            manifest = tests / "manifest.toml"
            manifest.unlink(missing_ok=True)
            tests.rmdir()
        raise
    print(f"Created {package.path}/package.toml and {package.tests}/manifest.toml.")


def create_function(project, args):
    name = matching(args.package, NAME, "package name")
    short = matching(args.name, NAME, "function name")
    symbol = f"{name}_{short}"
    packages = load_packages(project)
    if name not in packages:
        fail(name, "unknown extension package")
    package = packages[name]
    allowed = set(project.functions) | package.functions.keys()
    for dep in package.dependencies:
        allowed.update(packages[dep].functions)
    if unknown := set(args.depends) - allowed:
        fail(symbol, "undeclared function dependencies: " + ", ".join(sorted(unknown)))
    if symbol in project.functions or symbol in extension_functions(packages):
        fail(symbol, "function already exists")
    destination = confined(project.root, package.path / "spec/functions" / f"{symbol}.toml")
    destination.parent.mkdir(parents=True, exist_ok=True)
    values = {
        "name": symbol, "header": package.header, "prototype": args.prototype,
        "standard": [f"Extension ABI {package.name}"], "deps": args.depends, "errno": [],
        "mt_safe": args.mt_safe, "as_safe": args.as_safe, "oracles": [package.oracle],
        "provenance": "original", "semantics": args.semantics,
    }
    abi = {"narrow_args": args.narrow_arg, "variadic": "..." in args.prototype,
           "noreturn": "_Noreturn" in args.prototype.split()}
    def fields(table):
        return "".join(f"{key} = {json.dumps(value)}\n" for key, value in table.items())

    with NamedTemporaryFile(mode="w", encoding="utf-8", dir=destination.parent, delete=False) as file:
        temporary = Path(file.name)
        try:
            file.write(fields(values) + "\n[abi]\n" + fields(abi))
            file.flush()
            spec = load_function(temporary, project.root)
            destination.hardlink_to(temporary)
        finally:
            temporary.unlink()
    print(f"Created {destination.relative_to(project.root)}.\n"
          f"Independent tests belong in {package.tests}.\n"
          f"Use tools/gen --comment-header {symbol} for {package.source(symbol)}.")
    return spec


def scaffold(kind):
    parser = argparse.ArgumentParser(description=f"Scaffold an extension {kind} without a production implementation.")
    if kind == "package":
        parser.add_argument("name")
        parser.add_argument("--oracle", required=True)
        parser.add_argument("--stability", choices=("experimental", "stable"), default="experimental")
    else:
        parser.add_argument("package")
        parser.add_argument("name", help="function name without its package prefix")
        parser.add_argument("--prototype", required=True)
        parser.add_argument("--semantics", required=True, action="append")
        parser.add_argument("--narrow-arg", default=[], action="append")
        parser.add_argument("--mt-safe", action="store_true")
        parser.add_argument("--as-safe", action="store_true")
    parser.add_argument("--depends", default=[], action="append")
    args = parser.parse_args()
    try:
        project = load_project(ROOT)
        if kind == "package":
            create_package(project, args)
        else:
            create_function(project, args)
    except (SpecError, OSError, ValueError) as error:
        print(f"new-{kind}: {error}", file=sys.stderr)
        return 1
    return 0
