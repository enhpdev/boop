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
- [x] Linux Desktop and iOS app builds successfully using a devshell on Linux
- [x] iOS ipa successfully sideloads and launches
- [x] Buttons and related outputs are reactive
- [x] Bonus: Android also compiles and works!

### Phase 2: Multi-view apps with platform-specific layouts 

Goal: Run a simple application with multiple reactive views and viewmodels and
a stack-based navigator with different layouts (horizontal vs vertical) based
on the device settings (horizontal on mobile->landscape and desktop, otherwise
vertical). 

Note: The bigger change here is that we have to convert from synchronous
V/VM in the boop-app crate to async-compatible code, it's a big architectural
leap but it's assuredly possible. Testing will include a Stopwatch as one of
the navigable views. This phase also implements Windows and macOS as explicit
targets for completeness; a truly cross-platform app needs to be able to
compile for everything.

Success Criteria:
- [ ] Application has multiple navigable views
  - [ ] Backing out and returning retain information
- [ ] No memory leaks, tested via counting `Drop` invocations on VMs
- [ ] Application compiles and runs properly on all platforms
  - [ ] Android
  - [ ] iOS
  - [ ] Windows
  - [-] macOS (untestable currently)
  - [ ] Linux

### Phase 2.5: Proper CI/CD, including packaging

Goal: Implement cross-compilation build scripts and CI/CD workflows that 
compile all outputs and properly package them for the system they'll be running
on.

- [ ] CI/CD succeeds in producing artifacts for all platforms
  - [ ] Windows: .exe
  - [ ] macOS: .app
  - [ ] Linux: binary
  - [ ] iOS: .ipa
  - [ ] Android: .apk
- [ ] CI/CD succeeds in packaging artifacts for applicable platforms
  - [ ] iOS: Generate an AltStore source
  - [ ] macOS: .dmg and HomeBrew flask
  - [ ] Windows: .msi

