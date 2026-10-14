///|
pub struct BoolVar {
  priv value : Int32
} derive(Eq, Compare, Hash)

///|
#deprecated
#doc(hidden)
pub extend BoolVar with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend BoolVar with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated
#doc(hidden)
pub extend BoolVar with Hash::{hash, hash_combine}

///|
pub fn BoolVar::new(value : Int32) -> BoolVar {
  { value, }
}

///|
pub fn BoolVar::to_int(self : BoolVar) -> Int32 {
  self.value
}

///|
pub impl Show for BoolVar with fn output(self, logger) {
  logger.write_string("b\{self.value}")
}

///|
#deprecated
#doc(hidden)
pub extend BoolVar with Show::{to_string, output}

///|
pub struct Literal {
  priv bool_var : BoolVar
  priv positive : Bool
} derive(Eq)

///|
#deprecated
#doc(hidden)
pub extend Literal with Eq::{not_equal, equal}

///|
pub fn Literal::new(bool_var : BoolVar, positive : Bool) -> Literal {
  { bool_var, positive, }
}

///|
pub fn Literal::pos(bool_var : BoolVar) -> Literal {
  { bool_var, positive: true, }
}

///|
pub fn Literal::neg(bool_var : BoolVar) -> Literal {
  { bool_var, positive: false, }
}

///|
pub fn Literal::negate(self : Literal) -> Literal {
  { bool_var: self.bool_var, positive: !self.positive, }
}

///|
pub fn Literal::bool_var(self : Literal) -> BoolVar {
  self.bool_var
}

///|
pub fn Literal::is_positive(self : Literal) -> Bool {
  self.positive
}

///|
pub fn Literal::index(self : Literal) -> Int32 {
  2 * (self.bool_var.to_int() - 1) + (if self.positive { 0 } else { 1 })
}

///|
pub fn Literal::from_index(index : Int32) -> Literal {
  let bool_var = BoolVar::new(index / 2 + 1)
  if index % 2 == 0 {
    Literal::pos(bool_var)
  } else {
    Literal::neg(bool_var)
  }
}

///|
pub fn Literal::value(self : Literal, assignment : Array[Bool?]) -> Bool? {
  match assignment.get(self.bool_var.to_int()) {
    Some(Some(value)) => Some(value == self.positive)
    Some(None) | None => None
  }
}

///|
pub impl Show for Literal with fn output(self, logger) {
  if self.positive {
    logger.write_string("\{self.bool_var}")
  } else {
    logger.write_string("not \{self.bool_var}")
  }
}

///|
#deprecated
#doc(hidden)
pub extend Literal with Show::{to_string, output}
