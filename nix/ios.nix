# ios: cross-compiled binary, then an ad-hoc signed Payload/<app>.app zipped into an ipa
{ pkgs, meta, sdks, buildCrate, render }:

let
  i = meta.ios;
  llvm = sdks.llvm;
  sdk = sdks.iosSdkPatched;
  clangTarget = "--target=arm64-apple-ios${i.minVersion}";
  cflags = "${clangTarget} -isysroot ${sdk}";

  bin = buildCrate {
    crate = i.crate;
    target = i.target;
    nativeBuildInputs = [ llvm.lld ];

    env = {
      SDKROOT = sdk;
      IPHONEOS_DEPLOYMENT_TARGET = i.minVersion;
      SKIA_BINARIES_URL = sdks.skiaBinariesUrl;

      CARGO_TARGET_AARCH64_APPLE_IOS_LINKER = "${llvm.clang-unwrapped}/bin/clang";
      CARGO_TARGET_AARCH64_APPLE_IOS_RUSTFLAGS = toString [
        "-C link-arg=${clangTarget}"
        "-C link-arg=-isysroot"
        "-C link-arg=${sdk}"
        "-C link-arg=-fuse-ld=lld"
      ];

      CC_aarch64_apple_ios = "${llvm.clang-unwrapped}/bin/clang";
      CXX_aarch64_apple_ios = "${llvm.clang-unwrapped}/bin/clang++";
      AR_aarch64_apple_ios = "${llvm.llvm}/bin/llvm-ar";
      CFLAGS_aarch64_apple_ios = cflags;
      CXXFLAGS_aarch64_apple_ios = cflags;
    };

    installPhaseCommand = ''
      mkdir -p $out/bin
      cp target/${i.target}/release/${meta.app} $out/bin/
    '';

    # host strip/patchelf don't understand mach-o
    dontFixup = true;
  };

  plist = render "Info.plist" ../crates/boop/bin/client/mobile/ios/Info.plist.in;

  ipa = pkgs.runCommand "${meta.app}.ipa" {
    nativeBuildInputs = with pkgs; [ rcodesign zip ];
  } ''
    export HOME=$TMPDIR
    appdir=Payload/${meta.app}.app
    mkdir -p $appdir

    install -m755 ${bin}/bin/${meta.app} $appdir/${meta.app}
    cp ${plist} $appdir/Info.plist
    chmod -R u+w Payload

    # we love rcodesign (ad-hoc, no identity needed)
    rcodesign sign $appdir

    find Payload -exec touch -d @315532800 {} +
    zip -qrX $out Payload
  '';
in
{
  ios-bin = bin;
  inherit ipa;
}
