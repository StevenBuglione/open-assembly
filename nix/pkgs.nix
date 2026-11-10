let
  lock = builtins.fromJSON (builtins.readFile ../devenv.lock);
  pin = lock.nodes.nixpkgs.locked;
  source = builtins.getFlake "github:${pin.owner}/${pin.repo}/${pin.rev}?narHash=${pin.narHash}";
in source.legacyPackages.x86_64-linux
