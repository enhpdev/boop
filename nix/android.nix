# android: lib<app>.so + slint's classes.dex, then an aligned but unsigned apk.
# signing stays in the justfile since the debug keystore is impure state
{ pkgs, meta, sdks, buildCrate, render }:

let
  a = meta.android;
  linker = "${sdks.androidNdkBin}/${a.target}${a.minApi}-clang";

  so = buildCrate {
    crate = a.crate;
    target = a.target;
    nativeBuildInputs = [ pkgs.jdk17_headless ];

    env = {
      ANDROID_HOME = sdks.androidHome;
      ANDROID_SDK_ROOT = sdks.androidHome;
      ANDROID_NDK_HOME = sdks.androidNdk;
      ANDROID_NDK_ROOT = sdks.androidNdk;
      # slint's android build otherwise reads min-sdk as target-sdk
      ANDROID_JAR = sdks.androidJar;
      JAVA_HOME = pkgs.jdk17_headless.home;
      SKIA_BINARIES_URL = sdks.skiaBinariesUrl;

      CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER = linker;
      CC_aarch64_linux_android = linker;
      CXX_aarch64_linux_android = "${linker}++";
      AR_aarch64_linux_android = "${sdks.androidNdkBin}/llvm-ar";
    };

    installPhaseCommand = ''
      mkdir -p $out/lib/${a.abi}
      cp target/${a.target}/release/lib${meta.app}.so $out/lib/${a.abi}/

      # slint's java helper, compiled by its build script into the deps' target dir
      dex="$(find target/${a.target}/release/build \
               -path '*i-slint-backend-android-activity-*/out/classes.dex' | head -n1)"
      [ -n "$dex" ] || { echo "no classes.dex from i-slint-backend-android-activity" >&2; exit 1; }
      cp "$dex" $out/classes.dex
    '';

    # host strip/patchelf doesnt understand the aarch64 android .so
    dontFixup = true;
  };

  manifest = render "AndroidManifest.xml"
    ../crates/boop/bin/client/mobile/android/AndroidManifest.xml.in;

  apk-unsigned = pkgs.runCommand "${meta.app}-unsigned.apk" {
    nativeBuildInputs = [ pkgs.zip ];
  } ''
    bt=${sdks.androidBuildTools}
    mkdir staging && cd staging

    cp ${manifest} AndroidManifest.xml
    "$bt/aapt2" link -o base.apk --manifest AndroidManifest.xml -I ${sdks.androidJar}

    cp -r ${so}/lib ${so}/classes.dex .
    chmod -R u+w .
    # store files predate 1980, which zip can't encode
    find . -exec touch -d @315532800 {} +

    # apk entries are relative paths, so zip from inside the staging dir
    # -0: store the .so uncompressed so it can be page-aligned and mmapped
    zip -qrX0 base.apk lib
    zip -qrX base.apk classes.dex

    # page-align (16KB for newer devices; needs build-tools 35+)
    "$bt/zipalign" -f -P 16 4 base.apk $out
  '';
in
{
  android-so = so;
  inherit apk-unsigned;
}
