{ pkgs }:
let
  musl-gcc = pkgs.writeShellScriptBin "musl-gcc" ''
    unset LIBRARY_PATH
    exec ${pkgs.pkgsMusl.gcc}/bin/gcc "$@"
  '';
  al-clang = pkgs.writeShellScriptBin "al-clang" ''
    exec ${pkgs.llvmPackages.clang}/bin/clang "$@"
  '';
in with pkgs; [
  bashInteractive coreutils findutils gnugrep gnused gawk diffutils
  git nasm binutils gcc gnumake python3 file
  valgrind qemu-user musl glibc.static musl-gcc al-clang
]
