///|
fn clause_contains(literals : Array[Literal], literal : Literal) -> Bool {
  for existing in literals {
    if existing == literal {
      return true
    }
  }
  false
}

///|
pub struct Clause {
  priv literals : Array[Literal]
  priv tautology : Bool
} derive(Eq)

///|
pub fn Clause::new(literals : Array[Literal]) -> Clause {
  let normalized : Array[Literal] = []
  let mut tautology = false
  for literal in literals {
    if clause_contains(normalized, literal.negate()) {
      tautology = true
    } else if !clause_contains(normalized, literal) {
      normalized.push(literal)
    }
  }
  { literals: normalized, tautology }
}

///|
pub fn Clause::unit(literal : Literal) -> Clause {
  Clause::new([literal])
}

///|
pub fn Clause::empty() -> Clause {
  Clause::new([])
}

///|
pub fn Clause::literals(self : Clause) -> Array[Literal] {
  self.literals.copy()
}

///|
pub fn Clause::with_extra_literals(
  self : Clause,
  extra : Array[Literal],
) -> Clause {
  let literals = self.literals()
  for literal in extra {
    literals.push(literal)
  }
  Clause::new(literals)
}

///|
pub fn Clause::is_tautology(self : Clause) -> Bool {
  self.tautology
}

///|
pub fn Clause::contains_bool_var(self : Clause, bool_var : BoolVar) -> Bool {
  for literal in self.literals {
    if literal.bool_var() == bool_var {
      return true
    }
  }
  false
}

///|
pub fn Clause::has_var_above(self : Clause, max_var : BoolVar) -> Bool {
  for literal in self.literals {
    if literal.bool_var().to_int() > max_var.to_int() {
      return true
    }
  }
  false
}

///|
pub fn Clause::length(self : Clause) -> Int {
  self.literals.length()
}

///|
pub impl Show for Clause with fn output(self, logger) {
  logger.write_string("[")
  for i in 0..<self.literals.length() {
    if i > 0 {
      logger.write_string(", ")
    }
    logger.write_string("\{self.literals[i]}")
  }
  logger.write_string("]")
}
