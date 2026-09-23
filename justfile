app          := "boop"
display_name := "boop!"
bundle_id    := "dev.enhp.boop"
version      := "0.1.0"
min_os       := "15.0"

ios_target := "aarch64-apple-ios"
ios_crate  := "boop-bin-client-mobile-ios"
ios_src    := "crates/boop/bin/client/mobile/ios"

dist    := justfile_directory() / "dist"
payload := dist / "Payload"
appdir  := payload / (app + ".app")
ipa     := dist / (app + ".ipa")

default:
    @just --list

# run the desktop client
run:
    cargo run -p boop-bin-client-desktop

# compile the iOS binary
ios-build:
    cargo build --release --target {{ ios_target }} -p {{ ios_crate }}

# assemble Payload/<app>.app
ios-bundle: ios-build
    rm -rf {{ payload }}
    mkdir -p {{ appdir }}
    cp target/{{ ios_target }}/release/{{ app }} {{ appdir }}/{{ app }}
    chmod +x {{ appdir }}/{{ app }}
    sed -e 's|@APP@|{{ app }}|g' \
        -e 's|@DISPLAY_NAME@|{{ display_name }}|g' \
        -e 's|@BUNDLE_ID@|{{ bundle_id }}|g' \
        -e 's|@VERSION@|{{ version }}|g' \
        -e 's|@MIN_OS@|{{ min_os }}|g' \
        {{ ios_src }}/Info.plist.in > {{ appdir }}/Info.plist

# we love rcodesign
ios-sign: ios-bundle
    rcodesign sign {{ appdir }}

# produce dist/<app>.ipa
ios-ipa: ios-sign
    rm -f {{ ipa }}
    cd {{ dist }} && zip -qr {{ app }}.ipa Payload
    @echo "built {{ ipa }}"

# remove build outputs
clean:
    rm -rf {{ dist }}
    cargo clean
