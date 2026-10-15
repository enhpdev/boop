# platform sdks and the skia prebuilts slint's skia renderer needs on mobile
{ pkgs, meta }:

let
  lib = pkgs.lib;
in
rec {
  llvm = pkgs.llvmPackages_19;

  desktopRuntimeLibs = with pkgs; [
    libGL
    vulkan-loader
    libxkbcommon
    wayland
    fontconfig
    freetype
    libx11
    libxcursor
    libxi
    libxrandr
  ];

  # android

  androidComposition = pkgs.androidenv.composeAndroidPackages {
    platformVersions = [ meta.android.targetApi ];
    buildToolsVersions = [ meta.android.buildTools ];
    includeNDK = true;
    ndkVersions = [ meta.android.ndk ];
    includeEmulator = false;
    includeSystemImages = false;
  };
  androidSdk = androidComposition.androidsdk;
  androidHome = "${androidSdk}/libexec/android-sdk";
  androidNdk = "${androidHome}/ndk/${meta.android.ndk}";
  androidBuildTools = "${androidHome}/build-tools/${meta.android.buildTools}";
  androidJar = "${androidHome}/platforms/android-${meta.android.targetApi}/android.jar";
  androidNdkBin = "${androidNdk}/toolchains/llvm/prebuilt/linux-x86_64/bin";

  # ios

  iosSdk = pkgs.requireFile {
    name = "iPhoneOS27.0.sdk";
    hashMode = "recursive";
    hash = "sha256-BTRNSth1Y+8Q/qGU9JDRfun15MCQiri7I+pAyB7oqSA=";
    message = ''
      boop needs the iOS SDK in the nix store.
      extract iPhoneOS.sdk from Xcode.xip, rename it to iPhoneOS27.0.sdk, then run:
        nix-store --add-fixed --recursive sha256 ./iPhoneOS27.0.sdk
    '';
  };

  iosSdkPatched = pkgs.runCommand "iPhoneOS27.0-patched.sdk" { } ''
    cp -a ${iosSdk} $out
    chmod -R u+w $out
    grep -rl 'arm64e\.x1' $out --include='*.tbd' \
      | xargs -r sed -i \
          -e 's/, arm64e\.x1-ios//g' \
          -e 's/arm64e\.x1-ios, //g' \
          -e 's/arm64e\.x1-ios//g'
  '';

  # skia

  # skia-bindings downloads prebuilt skia in its build script, which the sandbox
  # forbids; fetch them up front and point SKIA_BINARIES_URL at the store instead.
  # bump these alongside slint (see `TRYING TO DOWNLOAD` in the skia-bindings build output)
  skiaBinaries =
    let
      tag = "0.153.3";
      fetch = key: hash: pkgs.fetchurl {
        url = "https://github.com/rust-skia/skia-binaries/releases/download/${tag}/skia-binaries-${key}.tar.gz";
        inherit hash;
      };
    in
    pkgs.linkFarm "skia-binaries-${tag}" (lib.mapAttrsToList (key: hash: {
      name = "skia-binaries-${key}.tar.gz";
      path = fetch key hash;
    }) {
      "b7f043e0b1e2a850e702-aarch64-linux-android-ganesh-gl-jpegd-jpege-pdf-vulkan" =
        "sha256-DZF7YI0DYy+oQo4A/3FbvlZj+JYYiTpeAmX/6j5s9Rk=";
      "b7f043e0b1e2a850e702-aarch64-apple-ios-ganesh-gl-jpegd-jpege-metal-pdf" =
        "sha256-EzJltb8pqyBxAIZp6TfpKDoZSDNW4Dtk1XkjSRb3ayU=";
    });
  skiaBinariesUrl = "file://${skiaBinaries}/skia-binaries-{key}.tar.gz";

  extractIosSdk = pkgs.writeShellApplication {
    name = "extract-ios-sdk";
    runtimeInputs = with pkgs; [ coreutils findutils xar pbzx cpio ];
    text = ''
      if [ $# -lt 1 ]; then
        echo "usage: extract-ios-sdk <Xcode.xip>" >&2
        exit 1
      fi

      xip="$(realpath "$1")"

      wd="$(mktemp -d)"
      trap 'rm -rf "$wd"' EXIT
      cd "$wd"

      mkdir xip
      echo "unxipping $xip to $wd/xip"
      xar -xf "$xip" -C xip/ Content

      echo "extracting SDK via pbzx | cpio (this takes a while)"
      pbzx -n xip/Content | cpio -idm "*/iPhoneOS.platform/Developer/SDKs/*"
      rm -rf xip/

      sdks="Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs"
      name="$(find "$sdks" -maxdepth 1 -name 'iPhoneOS[0-9]*.sdk' -printf '%f\n' | head -n1)"
      if [ -z "$name" ]; then
        echo "couldn't find a versioned iPhoneOS SDK in $sdks" >&2
        exit 1
      fi

      echo "copying real SDK dir out as $name"
      cp -a "$(realpath "$sdks/$name")" "./$name"

      echo "adding $name to the nix store"
      store_path="$(nix-store --add-fixed --recursive sha256 "./$name")"

      echo
      echo "name:  $name"
      echo "path:  $store_path"
      echo "hash:  $(nix hash path "./$name")"
    '';
  };
}
