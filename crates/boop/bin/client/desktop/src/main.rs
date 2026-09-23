fn main() -> Result<(), boop_app::PlatformError> {
    boop_app::RootView::new()?.run()
}
