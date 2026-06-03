///|
pub struct SmtLiteral {
  priv literal : @pure_sat.Literal
}

///|
pub fn SmtLiteral::new(literal : @pure_sat.Literal) -> SmtLiteral {
  { literal, }
}

///|
pub fn SmtLiteral::as_sat(self : SmtLiteral) -> @pure_sat.Literal {
  self.literal
}

///|
pub fn SmtLiteral::negate(self : SmtLiteral) -> SmtLiteral {
  { literal: self.literal.negate() }
}

///|
pub fn SmtLiteral::to_text(self : SmtLiteral) -> String {
  "\{self.literal}"
}
