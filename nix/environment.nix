{ pkgs }:
{
  LC_ALL = "C";
  PYTHONDONTWRITEBYTECODE = "1";
  LIBRARY_PATH = "${pkgs.glibc.static}/lib";
  OPEN_ASSEMBLY_GLIB_HEADERS = "${pkgs.glib.dev}/include/glib-2.0";
  OPEN_ASSEMBLY_GLIB_CONFIG = "${pkgs.glib.out}/lib/glib-2.0/include";
  OPEN_ASSEMBLY_LIBC_TEST = "${import ./libc-test.nix { inherit pkgs; }}";
  OPEN_ASSEMBLY_MPFR = "${pkgs.mpfr}/lib/libmpfr.so.6";
  OPEN_ASSEMBLY_FLOAT_VECTORS = "${import ./float-vectors.nix { inherit pkgs; }}";
}
