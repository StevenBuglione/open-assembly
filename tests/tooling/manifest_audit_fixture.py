"""Synthetic records for tooling schema controls, independent of API behavior."""

from copy import deepcopy
from pathlib import Path

from failure_journal import hash_json
from manifest_references import ASSERTIONS, MANIFEST, MANIFEST_SHA256, SOURCE, SOURCE_SHA256

MODEL = Path('tests/phase9/restartable/model.c')
HEADER = Path('build/include/c/wchar.h')


def sources(root):
    origin = Path(__file__).resolve().parents[2]
    paths = (MODEL, HEADER, MANIFEST, SOURCE)
    for relative in paths:
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes((origin / relative).read_bytes() if relative in (MANIFEST, SOURCE)
                         else b'synthetic tooling schema fixture\n')
    return paths


def records(inputs):
    headers = {HEADER.as_posix(): inputs[HEADER.as_posix()]}
    model = {'outcome': 'pass', 'source': MODEL.as_posix(), 'source_sha256': inputs[MODEL.as_posix()],
             'objects': {label: {'outcome': 'pass', 'object_sha256': '1' * 64, 'undefined_symbols': {},
                                'headers': headers, 'headers_sha256': hash_json(headers),
                                'dependency_file_sha256': '2' * 64} for label in ('candidate', 'glibc', 'musl')}}
    case = 'multibyte-scalar16'
    artifacts = {stage: {'test-0.o': '3' * 64, case: '4' * 64} for stage in ('first', 'second')}
    builds = {stage: {'test_object_sha256': '3' * 64, 'binary_sha256': '4' * 64,
                      'undefined_symbol': {'mbsinit': 'U'}, 'defined_symbol': {'mbsinit': 'T'}}
              for stage in ('first', 'second')}
    references = {'outcome': 'pass', 'bindings': {case: {'public_function': 'mbsinit',
        'manifest': MANIFEST.as_posix(), 'manifest_sha256': MANIFEST_SHA256,
        'source': SOURCE.as_posix(), 'source_sha256': SOURCE_SHA256,
        'original_requires': ['mbrtoc16', 'c16rtomb'], 'args': ['scalar16'],
        'assertions': list(ASSERTIONS), 'builds': builds}}}
    return deepcopy({'candidate_build': {'fixture_independence': model},
                     'native_oracles': {'required_references': references,
                                        'cases': {case: {'outcome': 'pass', 'artifacts': artifacts}}}})
