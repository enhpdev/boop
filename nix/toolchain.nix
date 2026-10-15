# one toolchain for the shells and the crane builds, so both share the same store path
{ pkgs, meta }:

pkgs.rust-bin.stable.latest.default.override {
  extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" ];
  targets = [
    meta.ios.target
    "aarch64-apple-ios-sim"
    meta.android.target
    "x86_64-linux-android"
  ];
}
