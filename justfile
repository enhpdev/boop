# artifacts are nix packages (see ./nix); this file keeps the impure bits:
# the cargo dev loop, debug signing with the local keystore, and device access

# global vars (keep in sync with nix/meta.nix)
app       := "boop"
bundle_id := "dev.enhp.boop"

# common build vars
build_dir := justfile_directory() / "target" / ".just"
dist_dir  := justfile_directory() / "dist"

ios_artifact     := dist_dir / (app + ".ipa")
android_artifact := dist_dir / (app + ".apk")

debug_keystore := justfile_directory() / ".boop" / "debug.keystore"

default:
    @just --list

# run the desktop client
run:
    cargo run -p boop-bin-client-desktop

# helper

_bootstrap:
    @mkdir -p {{ dist_dir }}
    @mkdir -p {{ build_dir }}

# desktop

# build the packaged desktop client into target/.just/desktop
desktop: _bootstrap
    nix build .#desktop --out-link {{ build_dir }}/desktop

# ios

# produce dist/<app>.ipa
ios-ipa: _bootstrap
    nix build .#ipa --out-link {{ build_dir }}/ipa
    install -m644 {{ build_dir }}/ipa {{ ios_artifact }}
    @echo "built artifact {{ ios_artifact }}"

# android

_require-android:
    @[ -n "${ANDROID_HOME:-}" ] || { echo "not in the android shell; run: nix develop .#android" >&2; exit 1; }
    @[ -n "${BOOP_ANDROID_BUILD_TOOLS:-}" ] || { echo "BOOP_ANDROID_BUILD_TOOLS unset" >&2; exit 1; }

# create a persistent debug keystore if missing
android-keystore:
    @mkdir -p "$(dirname {{ debug_keystore }})"
    @[ -f {{ debug_keystore }} ] || keytool -genkeypair -keystore {{ debug_keystore }} \
        -storepass android -keypass android -alias boop -keyalg RSA -keysize 2048 \
        -validity 10000 -dname "CN=boop debug"

# build the aligned apk with nix, then sign it with the local debug keystore
android-apk: _require-android _bootstrap android-keystore
    nix build .#apk-unsigned --out-link {{ build_dir }}/apk-unsigned
    "$BOOP_ANDROID_BUILD_TOOLS/apksigner" sign \
        --ks {{ debug_keystore }} --ks-pass pass:android \
        --out {{ android_artifact }} {{ build_dir }}/apk-unsigned
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
