{ pkgs }:
let
  lua = import ./lua.nix { inherit pkgs; };
  zlib = pkgs.fetchurl {
    url = "https://zlib.net/fossils/zlib-1.3.2.tar.gz";
    hash = "sha256-uzKaCizQJ00FUZ1hxmfAYuBpkNcuEl7i36jeZPARnRY=";
  };
  sqlite = import ./sqlite.nix { inherit pkgs; };
in {
  LC_ALL = "C";
  PYTHONDONTWRITEBYTECODE = "1";
  LIBRARY_PATH = "${pkgs.glibc.static}/lib";
  OPEN_ASSEMBLY_GLIB_HEADERS = "${pkgs.glib.dev}/include/glib-2.0";
  OPEN_ASSEMBLY_GLIB_CONFIG = "${pkgs.glib.out}/lib/glib-2.0/include";
  OPEN_ASSEMBLY_LUA_SOURCE = "${lua.source}";
  OPEN_ASSEMBLY_LUA_TESTS = "${lua.tests}";
  OPEN_ASSEMBLY_ZLIB_SOURCE = "${zlib}";
  OPEN_ASSEMBLY_SQLITE_SOURCE = "${sqlite.source}";
  OPEN_ASSEMBLY_SQLITE_AMALGAMATION = "${sqlite.amalgamation}";
  OPEN_ASSEMBLY_BUSYBOX_SOURCE = "${pkgs.busybox.src}";
  OPEN_ASSEMBLY_LIBC_TEST = "${import ./libc-test.nix { inherit pkgs; }}";
  OPEN_ASSEMBLY_OPEN_POSIX = "${import ./open-posix.nix { inherit pkgs; }}";
  OPEN_ASSEMBLY_GNULIB = "${import ./gnulib.nix { inherit pkgs; }}";
  OPEN_ASSEMBLY_VALGRIND_HEADERS = "${pkgs.valgrind.dev}/include";
  OPEN_ASSEMBLY_MPFR = "${pkgs.mpfr}/lib/libmpfr.so.6";
  OPEN_ASSEMBLY_FLOAT_VECTORS = "${import ./float-vectors.nix { inherit pkgs; }}";
}
