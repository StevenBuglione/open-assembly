{ pkgs }:
{
  source = pkgs.fetchurl {
    urls = [
      "https://www.lua.org/ftp/lua-5.4.9.tar.gz"
      "https://www.tecgraf.puc-rio.br/lua/local/ftp/lua-5.4.9.tar.gz"
    ];
    curlOptsList = [ "--connect-timeout" "15" "--retry" "1" ];
    hash = "sha256-IzW2xYKlJlT5RhK/ENL0ZygF0FMpqmVosdjNnlxvuOY=";
  };
  tests = pkgs.fetchurl {
    urls = [
      "https://www.lua.org/tests/lua-5.4.9-tests.tar.gz"
      "https://www.tecgraf.puc-rio.br/lua/local/tests/lua-5.4.9-tests.tar.gz"
    ];
    curlOptsList = [ "--connect-timeout" "15" "--retry" "1" ];
    hash = "sha256-fZcYRfVF/8CfuzEoqGssZSQWHHDQ/fAVShbowAw0P8o=";
  };
}
