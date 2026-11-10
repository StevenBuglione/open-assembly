{ pkgs }:
let
  source = pkgs.fetchurl {
    url = "https://archive.debian.org/debian-security/pool/updates/main/l/linux-signed-amd64/linux-image-4.19.0-27-amd64_4.19.316-1_amd64.deb";
    hash = "sha256-eGA6hbpOY0hpbv2JIySH5QljpYFgnyl10YziongbxyY=";
  };
in pkgs.runCommand "open-assembly-linux-4.19.316-bzImage" {
  nativeBuildInputs = [ pkgs.binutils pkgs.gnutar pkgs.xz ];
} ''
  ar p ${source} data.tar.xz | tar -xJOf - ./boot/vmlinuz-4.19.0-27-amd64 > "$out"
  echo "71947e2c7102ceb224b04b910c5761bc9f2a7986c2c8d868b5553dc8fef57747  $out" | sha256sum -c -
''
