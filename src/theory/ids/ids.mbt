///|
pub struct TheoryId {
  priv value : Int
} derive(Eq, Compare, Hash)

///|
pub fn TheoryId::new(value : Int) -> TheoryId {
  { value, }
}

///|
pub fn TheoryId::null() -> TheoryId {
  { value: -1 }
}

///|
pub fn TheoryId::to_int(self : TheoryId) -> Int {
  self.value
}

///|
pub impl Show for TheoryId with fn output(self, logger) {
  logger.write_string("th#\{self.value}")
}

///|
pub struct TheoryVar {
  priv value : Int
} derive(Eq, Compare, Hash)

///|
pub fn TheoryVar::new(value : Int) -> TheoryVar {
  { value, }
}

///|
pub fn TheoryVar::null() -> TheoryVar {
  { value: -1 }
}

///|
pub fn TheoryVar::to_int(self : TheoryVar) -> Int {
  self.value
}

///|
pub impl Show for TheoryVar with fn output(self, logger) {
  logger.write_string("v#\{self.value}")
}
