{
  description = "boop! - cross-platform rust + slint proof of concept";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, rust-overlay, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs {
        inherit system;
        overlays = [ rust-overlay.overlays.default ];
        config = {
          allowUnfree = true;
          android_sdk.accept_license = true;
        };
      }));
    in
    {
      devShells = forAllSystems (pkgs:
        let
          lib = pkgs.lib;
          llvm = pkgs.llvmPackages_19;

          rust = pkgs.rust-bin.stable.latest.default.override {
            extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" ];
            targets = [
              "aarch64-apple-ios"
              "aarch64-apple-ios-sim"
              "aarch64-linux-android"
              "x86_64-linux-android"
            ];
          };

          androidComposition = pkgs.androidenv.composeAndroidPackages {
            platformVersions = [ "35" ];
            buildToolsVersions = [ "35.0.0" ];
            includeNDK = true;
            ndkVersions = [ "27.2.12479018" ];
            includeEmulator = false;
            includeSystemImages = false;
          };
          androidSdk = androidComposition.androidsdk;
          androidMinApi = "26";

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

          commonPackages = with pkgs; [
            rust
            just
            pkg-config
            slint-lsp
            python3
            ninja
          ];

          desktopPackages = desktopRuntimeLibs ++ (with pkgs; [
            fontconfig.dev
            freetype.dev
          ]);

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

          # The iOS 27 SDK's .tbd stubs declare the arm64e.x1 arch, which LLVM 19's
          # TAPI reader rejects outright ("unknown architecture"), breaking every
          # link against the SDK. Strip it -- plain arm64 still resolves fine
          # against the remaining arm64e stubs, which is how real iOS apps link.
          iosSdkPatched = pkgs.runCommand "iPhoneOS27.0-patched.sdk" { } ''
            cp -a ${iosSdk} $out
            chmod -R u+w $out
            grep -rl 'arm64e\.x1' $out --include='*.tbd' \
              | xargs -r sed -i \
                  -e 's/, arm64e\.x1-ios//g' \
                  -e 's/arm64e\.x1-ios, //g' \
                  -e 's/arm64e\.x1-ios//g'
          '';

          iosPackages = [
            llvm.clang-unwrapped
            llvm.lld 
            llvm.llvm 
            pkgs.rcodesign
            pkgs.zip
            pkgs.unzip
            iosSdkPatched
          ];

          androidPackages = with pkgs; [
            androidSdk
            cargo-ndk
            jdk17_headless 
            smali
          ];

          desktopHook = ''
            export LD_LIBRARY_PATH="${lib.makeLibraryPath desktopRuntimeLibs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
          '';

          iosHook = ''
            export SDKROOT="''${BOOP_IOS_SDK:-${iosSdkPatched}}"
            export IPHONEOS_DEPLOYMENT_TARGET=15.0

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
            export ANDROID_HOME="${androidSdk}/libexec/android-sdk"
            export ANDROID_SDK_ROOT="$ANDROID_HOME"
            export ANDROID_NDK_HOME="$(echo "$ANDROID_HOME"/ndk/* | head -n1)"
            export ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"
            export BOOP_ANDROID_MIN_API=${androidMinApi}

            export BOOP_ANDROID_BUILD_TOOLS="$(echo "$ANDROID_HOME"/build-tools/* | head -n1)"

            ndk_bin="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"
            export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$ndk_bin/aarch64-linux-android${androidMinApi}-clang"
            export CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER="$ndk_bin/x86_64-linux-android${androidMinApi}-clang"
          '';

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
            packages = [ extractIosSdk ];
          };
        });
    };
}
