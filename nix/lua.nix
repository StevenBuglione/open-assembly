{ pkgs }:
{
  source = pkgs.fetchurl {
    url = "https://www.lua.org/ftp/lua-5.4.9.tar.gz";
    hash = "sha256-IzW2xYKlJlT5RhK/ENL0ZygF0FMpqmVosdjNnlxvuOY=";
  };
  tests = pkgs.fetchurl {
    url = "https://www.lua.org/tests/lua-5.4.9-tests.tar.gz";
    hash = "sha256-fZcYRfVF/8CfuzEoqGssZSQWHHDQ/fAVShbowAw0P8o=";
  };
}
