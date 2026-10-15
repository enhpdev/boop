# app identity shared by every package (the justfile mirrors the few it still needs)
{
  app = "boop";
  displayName = "boop!";
  bundleId = "dev.enhp.boop";
  version = "0.1.0";
  versionCode = "1";

  ios = {
    target = "aarch64-apple-ios";
    crate = "boop-bin-client-mobile-ios";
    minVersion = "15.0";
  };

  android = {
    target = "aarch64-linux-android";
    abi = "arm64-v8a";
    crate = "boop-bin-client-mobile-android";
    minApi = "26";
    targetApi = "35";
    buildTools = "35.0.0";
    ndk = "27.2.12479018";
  };

  desktop.crate = "boop-bin-client-desktop";
}
