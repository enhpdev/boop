#[unsafe(no_mangle)]
#[cfg(target_os = "android")]
fn android_main(app: boop_app::android::AndroidApp) {
    boop_app::android::init(app).unwrap();
    boop_app::RootView::new().unwrap().run().unwrap();
}