#!/usr/bin/env bash
# Run from the checkout root so the development headers use the project pin.
set -euo pipefail
directory=${1:?usage: native_headers.sh output-directory}
mkdir -p "$directory"
mpfr_dev=$(nix build --no-link --impure --print-out-paths --expr '(import ./nix/pkgs.nix).mpfr.dev')
gmp_dev=$(nix build --no-link --impure --print-out-paths --expr '(import ./nix/pkgs.nix).gmp.dev')
cp "$mpfr_dev/include/mpfr.h" "$gmp_dev/include/gmp.h" "$directory/"
