#!/bin/sh
# Exercise the production controls in a disposable checkout.
set -eu
cd "$(dirname "$0")/../../../.."
tests/tooling/extensions/setup.sh
fixtures=tests/tooling/extensions/production
cp "$fixtures/word_math_clamp_u32.asm" ext/word_math/src/x86_64-linux/
cp "$fixtures/packets.c" "$fixtures/production.toml" tests/ext/word_math/
cat "$fixtures/packet-case.toml" >> tests/ext/word_math/manifest.toml
mkdir -p tests/oracle/word_math
cp "$fixtures/model.py" tests/oracle/word_math/model.py
tools/extension-gate word_math --require-production
