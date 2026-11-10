#!/bin/sh
# Set up a verification-only package in a disposable checkout.
set -eu
cd "$(dirname "$0")/../../.."
fixtures=tests/tooling/extensions
tools/new-package word_math --oracle reference:unsigned-minimum
tools/new-function word_math clamp_u32 \
  --prototype 'unsigned int word_math_clamp_u32(unsigned int value, unsigned int ceiling)' \
  --narrow-arg edi:u32 --narrow-arg esi:u32 --mt-safe --as-safe \
  --semantics 'Return the smaller of value and ceiling, compared as unsigned 32-bit integers.' \
  --semantics 'Do not access memory or modify errno.'
mkdir -p build/extension-controls
if tools/extension-gate word_math > build/extension-controls/unimplemented.log 2>&1; then
    exit 1
fi
grep -q 'unimplemented extension functions: ext/word_math/src/x86_64-linux/word_math_clamp_u32.asm' \
    build/extension-controls/unimplemented.log
cp build/evidence/extension-word_math.json build/extension-controls/unimplemented.json
mkdir -p ext/word_math/src/x86_64-linux
cp "$fixtures/word_math_clamp_u32.asm" ext/word_math/src/x86_64-linux/
cp "$fixtures/check.c" "$fixtures/manifest.toml" tests/ext/word_math/
if tools/extension-gate word_math --require-production > build/extension-controls/required.log 2>&1; then
    exit 1
fi
grep -q 'coverage, mutation and timed fuzzing require' build/extension-controls/required.log
cp build/evidence/extension-word_math.json build/extension-controls/required.json
tools/gen
tools/extension-gate word_math
