///|
pub struct Model {
  consts : Map[String, (Sort, Term)]
} derive(Show, Eq)

///|
pub fn Model::new() -> Model {
  { consts: Map::new() }
}

///|
pub fn Model::set(
  self : Model,
  name : String,
  sort : Sort,
  value : Term,
) -> Unit {
  self.consts[name] = (sort, value)
}

///|
pub fn Model::get(self : Model, name : String) -> (Sort, Term)? {
  self.consts.get(name)
}

///|
pub fn term_to_smt2(term : Term) -> String {
  match term {
    Term::BoolVal(value) => if value { "true" } else { "false" }
    Term::IntVal(value) => "\{value}"
    Term::RealVal(value) => value
    Term::BitVecVal(value) => value.repr
    Term::FpVal(value) =>
      "(fp \{value.sign.repr} \{value.exponent.repr} \{value.significand.repr})"
    Term::Var(name, _) => name
    Term::App(decl, args) =>
      if args.length() == 0 {
        decl.name
      } else {
        let args_s = args.map(term_to_smt2).join(" ")
        "(\{decl.name} \{args_s})"
      }
    _ => term.to_string()
  }
}

///|
pub fn Model::to_smt2(self : Model) -> String {
  let lines : Array[String] = ["(model"]
  for name, entry in self.consts {
    let (sort, value) = entry
    let val_str = term_to_smt2(value)
    lines.push("  (define-fun \{name} () \{sort.to_string()} \{val_str})")
  }
  lines.push(")")
  lines.join("\n")
}
