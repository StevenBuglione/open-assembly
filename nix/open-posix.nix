{ pkgs }:
pkgs.fetchurl {
  name = "open-assembly-ltp-20260930.tar.gz";
  url = "https://codeload.github.com/linux-test-project/ltp/tar.gz/2279d708c817db657611a30c427c7d06c4360049";
  hash = "sha256-NRRssdDoJReqyNvvvYi9ljAM44Nzaq4GnkNf2ZHqULs=";
}
