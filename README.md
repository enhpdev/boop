# `boop!`

Proof of Concept full-stack independent cross-platform app built from one 
rust codebase. Uses Rust, an MVVM architecture, Slint, Actix, Tokio, and
various other things.

## crates

- `boop-common`: Common type definitions, functions, and runtime primitives
- `boop-app`: Cross-platform ViewModel and View implementations
- `boop-runtime-server`: Core server runtime
- `boop-runtime-client`: Core client runtime
- `boop-platform`: Rust-side generic code for platform-specific abstractions
- `boop-platform-desktop`: Desktop of platform abstractions
- `boop-platform-mobile-android`: Android implementation of platform abstractions
- `boop-platform-mobile-ios`: iOS implementation of platform abstractions
- `boop-bin-server`: Server build target
- `boop-bin-client-desktop`: Desktop client build target
- `boop-bin-client-mobile-android`: Android client build target
- `boop-bin-client-mobile-ios`: iOS client build target

## proof-of-concept phases

### Phase 1: Hello World, Reactivity, and iOS.

Goal: Run a basic Hello World application with reactivity to UI activation 
(such as a button press on Add/Subtract) by redrawing the UI with changed data
(such as a running total) on desktop-linux and mobile-ios

Success Criteria: 
- [ ] Linux Desktop and iOS app builds successfully using a devshell on Linux
- [ ] iOS ipa successfully sideloads and launches
- [ ] Buttons and related outputs are reactive