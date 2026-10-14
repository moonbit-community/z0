///|
pub struct TheoryId {
  priv value : Int32
} derive(Eq, Compare, Hash)

///|
#deprecated
#doc(hidden)
pub extend TheoryId with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend TheoryId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated
#doc(hidden)
pub extend TheoryId with Hash::{hash, hash_combine}

///|
pub fn TheoryId::new(value : Int32) -> TheoryId {
  { value, }
}

///|
pub fn TheoryId::null() -> TheoryId {
  { value: -1, }
}

///|
pub fn TheoryId::to_int(self : TheoryId) -> Int32 {
  self.value
}

///|
pub impl Show for TheoryId with fn output(self, logger) {
  logger.write_string("th#\{self.value}")
}

///|
#deprecated
#doc(hidden)
pub extend TheoryId with Show::{to_string, output}

///|
pub struct TheoryVar {
  priv value : Int32
} derive(Eq, Compare, Hash)

///|
#deprecated
#doc(hidden)
pub extend TheoryVar with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend TheoryVar with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated
#doc(hidden)
pub extend TheoryVar with Hash::{hash, hash_combine}

///|
pub fn TheoryVar::new(value : Int32) -> TheoryVar {
  { value, }
}

///|
pub fn TheoryVar::null() -> TheoryVar {
  { value: -1, }
}

///|
pub fn TheoryVar::to_int(self : TheoryVar) -> Int32 {
  self.value
}

///|
pub impl Show for TheoryVar with fn output(self, logger) {
  logger.write_string("v#\{self.value}")
}

///|
#deprecated
#doc(hidden)
pub extend TheoryVar with Show::{to_string, output}
