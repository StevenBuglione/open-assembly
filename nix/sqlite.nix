{ pkgs }:
{
  source = pkgs.fetchurl {
    url = "https://www.sqlite.org/2026/sqlite-src-3530300.zip";
    hash = "sha256-u4C/ijv/wZJBzoq6WkvHTpw5gAE8sLXw8JdqmVFpQq8=";
  };
  amalgamation = pkgs.fetchurl {
    url = "https://www.sqlite.org/2026/sqlite-amalgamation-3530300.zip";
    hash = "sha256-ZGQh4SqsEQKC74zGjxpi1LsV/HuPCdoLU+Ke5pBQBDE=";
  };
}
