{ pkgs }:
pkgs.fetchgit {
  name = "open-assembly-libc-test";
  url = "https://repo.or.cz/libc-test.git";
  rev = "63e36e934e8f2bedf645303a90b64098e2af6c8f";
  hash = "sha256-6oaoIwCFRxcPh2xZrexpU7epIGG5AOAsRzg4gCc8mvQ=";
}
