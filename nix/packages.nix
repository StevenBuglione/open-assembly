{ pkgs }:
with pkgs; [
  bashInteractive coreutils findutils gnugrep gnused gawk diffutils
  git nasm binutils gcc gnumake python3 file
  valgrind qemu-user musl glibc.static
]
