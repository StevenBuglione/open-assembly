{ pkgs }:
let
  revision = "55d79b184b7d8fac2e143e89dc19b766ec4e54b8";
  upstream = "https://raw.githubusercontent.com/nigeltao/parse-number-fxx-test-data/${revision}";
  vectors = pkgs.fetchurl {
    url = "${upstream}/data/more-test-cases.txt";
    hash = "sha256-6ofsSUVxLsrVY7qPcowBXUrmi+2SqxKKi0QLCr8WgUg=";
  };
  license = pkgs.fetchurl {
    url = "${upstream}/LICENSE";
    hash = "sha256-xx0jnfkXJvxRnG63LTGOxlggYnIysveWIZ6H3PNdCrQ=";
  };
in pkgs.runCommand "open-assembly-float-vectors" { } ''
  mkdir -p "$out"
  cp ${vectors} "$out/vectors.txt"
  cp ${license} "$out/LICENSE"
''
