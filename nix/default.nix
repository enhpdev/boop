# wires the pieces together; flake.nix only picks systems and inputs
{ pkgs, crane }:

let
  lib = pkgs.lib;
  meta = import ./meta.nix;
  toolchain = import ./toolchain.nix { inherit pkgs meta; };
  sdks = import ./sdks.nix { inherit pkgs meta; };
  inherit (import ./crane.nix { inherit pkgs crane meta toolchain; }) buildCrate render;

  args = { inherit pkgs meta sdks buildCrate render; };

  desktop = import ./desktop.nix (removeAttrs args [ "render" ]);

  # the NDK and the iOS cross setup are wired for x86_64-linux hosts
  mobile = lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux")
    (import ./android.nix args // import ./ios.nix args);
in
{
  shells = import ./shells.nix { inherit pkgs meta toolchain sdks; };

  packages = {
    inherit desktop;
    default = desktop;
  } // mobile;
}
