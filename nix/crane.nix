# crane setup shared by every package: one source filter, one way to split deps
{ pkgs, crane, meta, toolchain }:

let
  lib = pkgs.lib;
  craneLib = (crane.mkLib pkgs).overrideToolchain (_: toolchain);
  root = ../.;
in
rec {
  inherit craneLib;

  # cargo sources plus the slint ui files the build scripts compile
  src = lib.fileset.toSource {
    inherit root;
    fileset = lib.fileset.unions [
      (craneLib.fileset.commonCargoSources root)
      (lib.fileset.fileFilter (f: f.hasExt "slint") ../crates)
    ];
  };

  # build one workspace member for one target. third-party deps live in their own
  # derivation per (crate, target), so they only rebuild when Cargo.lock or env changes
  buildCrate = { crate, target ? null, env ? { }, nativeBuildInputs ? [ ], buildInputs ? [ ], ... }@args:
    let
      extra = removeAttrs args [ "crate" "target" "env" "nativeBuildInputs" "buildInputs" ];
      common = env // {
        inherit src nativeBuildInputs buildInputs;
        pname = crate;
        version = meta.version;
        strictDeps = true;
        doCheck = false;
        cargoExtraArgs = "--locked -p ${crate}";
      } // lib.optionalAttrs (target != null) {
        CARGO_BUILD_TARGET = target;
      };

      cargoArtifacts = craneLib.buildDepsOnly (common // {
        # skip crane's default `cargo check --all-targets` pass; we only ever build
        buildPhaseCargoCommand = "cargoWithProfile build ${common.cargoExtraArgs}";
      });
    in
    craneLib.buildPackage (common // { inherit cargoArtifacts; } // extra);

  # fill @PLACEHOLDERS@ in a template (replaces the justfile's _render)
  render = name: template: pkgs.runCommand name { } ''
    sed -e 's|@APP@|${meta.app}|g' \
        -e 's|@DISPLAY_NAME@|${meta.displayName}|g' \
        -e 's|@BUNDLE_ID@|${meta.bundleId}|g' \
        -e 's|@VERSION@|${meta.version}|g' \
        -e 's|@VERSION_CODE@|${meta.versionCode}|g' \
        -e 's|@MIN_OS@|${meta.ios.minVersion}|g' \
        -e 's|@MIN_API@|${meta.android.minApi}|g' \
        -e 's|@TARGET_API@|${meta.android.targetApi}|g' \
        ${template} > $out
  '';
}
