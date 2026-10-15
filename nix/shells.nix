# dev shells for the cargo edit/run loop and the remaining justfile recipes
{ pkgs, meta, toolchain, sdks }:

let
  lib = pkgs.lib;

  commonPackages = with pkgs; [
    toolchain
    just
    pkg-config
    slint-lsp
    python3
    ninja
  ];

  desktopPackages = sdks.desktopRuntimeLibs ++ (with pkgs; [
    fontconfig.dev
    freetype.dev
  ]);

  iosPackages = [
    sdks.llvm.clang-unwrapped
    sdks.llvm.lld
    sdks.llvm.llvm
    pkgs.rcodesign
    pkgs.zip
    pkgs.unzip
    sdks.iosSdkPatched
  ];

  androidPackages = with pkgs; [
    sdks.androidSdk
    cargo-ndk
    jdk17_headless
  ];

  desktopHook = ''
    export LD_LIBRARY_PATH="${lib.makeLibraryPath sdks.desktopRuntimeLibs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  '';

  iosHook = ''
    export SDKROOT="''${BOOP_IOS_SDK:-${sdks.iosSdkPatched}}"
    export IPHONEOS_DEPLOYMENT_TARGET=${meta.ios.minVersion}

    if [ ! -d "$SDKROOT" ]; then
      echo "boop: warning: no iOS SDK at $SDKROOT (set BOOP_IOS_SDK)" >&2
    fi

    ios_target="--target=arm64-apple-ios$IPHONEOS_DEPLOYMENT_TARGET"

    export CARGO_TARGET_AARCH64_APPLE_IOS_LINKER=clang
    export CARGO_TARGET_AARCH64_APPLE_IOS_RUSTFLAGS="-C link-arg=$ios_target -C link-arg=-isysroot -C link-arg=$SDKROOT -C link-arg=-fuse-ld=lld"

    export CC_aarch64_apple_ios=clang
    export CXX_aarch64_apple_ios=clang++
    export AR_aarch64_apple_ios=llvm-ar
    export CFLAGS_aarch64_apple_ios="$ios_target -isysroot $SDKROOT"
    export CXXFLAGS_aarch64_apple_ios="$ios_target -isysroot $SDKROOT"
  '';

  androidHook = ''
    export ANDROID_HOME="${sdks.androidHome}"
    export ANDROID_SDK_ROOT="$ANDROID_HOME"
    export ANDROID_NDK_HOME="${sdks.androidNdk}"
    export ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"
    export BOOP_ANDROID_MIN_API=${meta.android.minApi}
    export BOOP_ANDROID_TARGET_API=${meta.android.targetApi}

    # fix niche bug where cargo-ndk emits min-sdk in a way slint's android
    # build reads as target-sdk by explicitly setting ANDROID_JAR location
    export ANDROID_JAR="${sdks.androidJar}"

    export BOOP_ANDROID_BUILD_TOOLS="${sdks.androidBuildTools}"

    export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="${sdks.androidNdkBin}/aarch64-linux-android${meta.android.minApi}-clang"
    export CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER="${sdks.androidNdkBin}/x86_64-linux-android${meta.android.minApi}-clang"
  '';

  mkShell = { name, packages, hooks }: pkgs.mkShell {
    inherit name;
    packages = commonPackages ++ packages;
    shellHook = lib.concatStringsSep "\n" hooks + ''
      echo "boop: entered ${name} shell"
    '';
  };
in
{
  default = mkShell {
    name = "boop-desktop";
    packages = desktopPackages;
    hooks = [ desktopHook ];
  };

  ios = mkShell {
    name = "boop-ios";
    packages = desktopPackages ++ iosPackages;
    hooks = [ desktopHook iosHook ];
  };

  android = mkShell {
    name = "boop-android";
    packages = desktopPackages ++ androidPackages;
    hooks = [ desktopHook androidHook ];
  };

  full = mkShell {
    name = "boop-full";
    packages = desktopPackages ++ iosPackages ++ androidPackages;
    hooks = [ desktopHook iosHook androidHook ];
  };

  extract-ios-sdk = pkgs.mkShell {
    name = "extract-ios-sdk";
    packages = [ sdks.extractIosSdk ];
  };
}
