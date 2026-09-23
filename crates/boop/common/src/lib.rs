
pub struct MyAwesomeSharedStructure {
  internal: i64
}

impl MyAwesomeSharedStructure {
    pub fn new(start: i64) -> Self {
        Self { internal: start }
    }
    pub fn increment(&mut self, by: i64) {
        self.internal += by;
    }
    pub fn decrement(&mut self, by: i64) {
        self.internal -= by;
    }
    pub fn fizzbuzz(&self) -> String {
        if (self.internal % 3) == 0 && (self.internal % 5) == 0 {
            String::from("FizzBuzz!")
        } else if self.internal % 5 == 0 {
            String::from("Buzz!")
        } else if self.internal % 3 == 0 {
            String::from("Fizz!")
        } else {
            String::from("")
        }
    }
}