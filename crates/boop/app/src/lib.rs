use std::{cell::RefCell, rc::Rc};

slint::include_modules!();

/// Re-exported so entry-point crates need no direct Slint dependency.
pub use slint::PlatformError;
#[cfg(target_os = "android")]
pub use slint::android;


pub struct RootViewModel {
    shared: boop_common::MyAwesomeSharedStructure
}
impl RootViewModel {
    pub fn new() -> Self {
        Self {
            shared: boop_common::MyAwesomeSharedStructure::new(0)
        }
    }
    pub fn increment(&mut self) { self.shared.increment(1); }
    pub fn decrement(&mut self) { self.shared.decrement(1); }

    pub fn counter(&self) -> i32 { self.shared.value() }
    pub fn fizzbuzz(&self) -> String { self.shared.fizzbuzz() }
}

pub struct RootView {
    view: AppWindow,
    vm: Rc<RefCell<RootViewModel>>
}
impl RootView {
    pub fn new() -> Result<Self, slint::PlatformError> {
        let view = AppWindow::new()?;
        let vm = Rc::new(RefCell::new(RootViewModel::new()));

        // a little bit of a hacky solution to keep from dangling AppWindow references
        let bind = |f: fn(&mut RootViewModel)| {
            let weak = view.as_weak();
            let vm = Rc::clone(&vm);
            move || {
                f(&mut vm.borrow_mut());
                if let Some(v) = weak.upgrade() {
                    Self::sync(&v, &vm.borrow());
                }
            }
        };

        view.on_increment(bind(RootViewModel::increment));
        view.on_decrement(bind(RootViewModel::decrement));
        Self::sync(&view, &vm.borrow());
        Ok(Self { view, vm })
    }
    fn sync(view: &AppWindow, vm: &RootViewModel) {
        view.set_counter(vm.counter());
        view.set_fizzbuzz(vm.fizzbuzz().into());
    }
    pub fn window(&self) -> &AppWindow {
        &self.view
    }
    pub fn run(&self) -> Result<(), slint::PlatformError> {
        self.view.run()
    }
}