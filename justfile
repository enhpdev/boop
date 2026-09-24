# global vars
app          := "boop"
display_name := "boop!"
bundle_id    := "dev.enhp.boop"
app_version  := "0.1.0"
version_code := "1"

# common build vars
build_dir := justfile_directory() / "target" / ".just"
dist_dir  := justfile_directory() / "dist"

# ios build vars
min_ios_ver  := "15.0"
ios_target   := "aarch64-apple-ios"
ios_crate    := "boop-bin-client-mobile-ios"
ios_src      := "crates/boop/bin/client/mobile/ios"
ios_build    := build_dir / "iOS"
ios_payload  := ios_build / "Payload"
ios_appdir   := ios_payload / (app + ".app")
ios_artifact := dist_dir / (app + ".ipa")

# android build vars
android_min_api    := "26"
android_target_api := "35"
android_abi        := "arm64-v8a"
android_target     := "aarch64-linux-android"
android_crate      := "boop-bin-client-mobile-android"
android_src        := "crates/boop/bin/client/mobile/android"
android_build      := build_dir / "Android"
android_staging    := android_build / "staging"
android_artifact   := dist_dir / (app + ".apk")

debug_keystore := justfile_directory() / ".boop" / "debug.keystore"

default:
    @just --list

# run the desktop client
run:
    cargo run -p boop-bin-client-desktop

# helper

# fill @PLACEHOLDERS@ in a template
_render in out:
    sed -e 's|@APP@|{{ app }}|g' \
        -e 's|@DISPLAY_NAME@|{{ display_name }}|g' \
        -e 's|@BUNDLE_ID@|{{ bundle_id }}|g' \
        -e 's|@VERSION@|{{ app_version }}|g' \
        -e 's|@VERSION_CODE@|{{ version_code }}|g' \
        -e 's|@MIN_OS@|{{ min_ios_ver }}|g' \
        -e 's|@MIN_API@|{{ android_min_api }}|g' \
        -e 's|@TARGET_API@|{{ android_target_api }}|g' \
        {{ in }} > {{ out }}

_bootstrap:
    @mkdir -p {{ dist_dir }}
    @mkdir -p {{ build_dir }}

# desktop



# ios

# compile the iOS binary
ios-build:
    cargo build --release --target {{ ios_target }} -p {{ ios_crate }}

# assemble Payload/<app>.app
ios-bundle: ios-build
    rm -rf {{ ios_payload }}
    mkdir -p {{ ios_appdir }}
    cp target/{{ ios_target }}/release/{{ app }} {{ ios_appdir }}/{{ app }}
    chmod +x {{ ios_appdir }}/{{ app }}
    sed -e 's|@APP@|{{ app }}|g' \
        -e 's|@DISPLAY_NAME@|{{ display_name }}|g' \
        -e 's|@BUNDLE_ID@|{{ bundle_id }}|g' \
        -e 's|@VERSION@|{{ app_version }}|g' \
        -e 's|@MIN_OS@|{{ min_ios_ver }}|g' \
        {{ ios_src }}/Info.plist.in > {{ ios_appdir }}/Info.plist

# we love rcodesign
ios-sign: ios-bundle
    rcodesign sign {{ ios_appdir }}

# produce dist/<app>.ipa
ios-ipa: _bootstrap ios-sign
    rm -f {{ ios_artifact }}
    cd {{ ios_build }} && zip -qr {{ ios_artifact }} Payload
    @echo "built artifact {{ ios_artifact }}"

# android

_require-android:
    @[ -n "${ANDROID_HOME:-}" ] || { echo "not in the android shell; run: nix develop .#android" >&2; exit 1; }
    @[ -n "${BOOP_ANDROID_BUILD_TOOLS:-}" ] || { echo "BOOP_ANDROID_BUILD_TOOLS unset" >&2; exit 1; }

# compile lib<app>.so into dist/android/stage/lib/<abi>/
android-build: _require-android
    rm -rf {{ android_staging }}
    cargo ndk -t {{ android_abi }} -P {{ android_min_api }} -o {{ android_staging }}/lib \
        build --release -p {{ android_crate }}
    @[ -f {{ android_staging }}/lib/{{ android_abi }}/lib{{ app }}.so ] \
        || { echo "expected {{ android_staging }}/lib/{{ android_abi }}/lib{{ app }}.so" >&2; exit 1; }

# compile the manifest into a base apk with aapt2
android-bundle: android-build
    just _render {{ android_src }}/AndroidManifest.xml.in {{ android_staging }}/AndroidManifest.xml
    "$BOOP_ANDROID_BUILD_TOOLS/aapt2" link \
        -o {{ android_staging }}/base.apk \
        --manifest {{ android_staging }}/AndroidManifest.xml \
        -I "$ANDROID_HOME/platforms/android-{{ android_target_api }}/android.jar"
    # finding slint's android helper
    dex="$(find target/{{ android_target }}/release/build \
             -path '*i-slint-backend-android-activity*/out/classes.dex' \
             -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n1 | cut -d' ' -f2-)"; \
    [ -n "$dex" ] || { echo "no classes.dex found; did android-build run?" >&2; exit 1; }; \
    cp "$dex" {{ android_staging }}/classes.dex
    # apk entries are relative paths, so zip from inside the staging dir
    # -0: store the .so uncompressed so it can be page-aligned and mmapped
    cd {{ android_staging }} && zip -qr0 base.apk lib
    cd {{ android_staging }} && zip -qr base.apk classes.dex

# page-align (16KB for newer devices; needs build-tools 35+)
android-align: android-bundle
    "$BOOP_ANDROID_BUILD_TOOLS/zipalign" -f -P 16 4 {{ android_staging }}/base.apk {{ android_staging }}/aligned.apk

# create a persistent debug keystore if missing
android-keystore:
    @mkdir -p "$(dirname {{ debug_keystore }})"
    @[ -f {{ debug_keystore }} ] || keytool -genkeypair -keystore {{ debug_keystore }} \
        -storepass android -keypass android -alias boop -keyalg RSA -keysize 2048 \
        -validity 10000 -dname "CN=boop debug"

# sign
android-apk: _bootstrap android-align android-keystore
    "$BOOP_ANDROID_BUILD_TOOLS/apksigner" sign \
        --ks {{ debug_keystore }} --ks-pass pass:android \
        --out {{ android_artifact }} {{ android_staging }}/aligned.apk
    "$BOOP_ANDROID_BUILD_TOOLS/apksigner" verify {{ android_artifact }}
    @echo "built artifact {{ android_artifact }}"

# install on the connected device and launch
android-install: android-apk
    adb install -r {{ android_artifact }}
    adb shell monkey -p {{ bundle_id }} -c android.intent.category.LAUNCHER 1

# follow logs for the app
android-log:
    adb logcat --pid="$(adb shell pidof -s {{ bundle_id }})"

# housekeeping

# remove build outputs
clean:
    rm -rf {{ dist_dir }}
    cargo clean
