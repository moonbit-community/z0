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
fn hex_digit(value : Int) -> Char? {
  match value {
    0 => Some('0')
    1 => Some('1')
    2 => Some('2')
    3 => Some('3')
    4 => Some('4')
    5 => Some('5')
    6 => Some('6')
    7 => Some('7')
    8 => Some('8')
    9 => Some('9')
    10 => Some('a')
    11 => Some('b')
    12 => Some('c')
    13 => Some('d')
    14 => Some('e')
    15 => Some('f')
    _ => None
  }
}

///|
fn bitvec_to_smt2(value : BitVecValue) -> String {
  let text = value.repr
  if value.width > 0 && value.width % 4 == 0 && text.has_prefix("#b") {
    let digits = value.width / 4
    let sb = StringBuilder::new()
    sb..write_string("#x")
    for i in 0..<digits {
      let mut nibble = 0
      let mut count = 0
      let start = 2 + i * 4
      for idx, ch in text.iter2() {
        if idx < start {
          continue
        }
        if idx >= start + 4 {
          break
        }
        count = count + 1
        match ch {
          '0' => nibble = nibble * 2
          '1' => nibble = nibble * 2 + 1
          _ => return text
        }
      }
      if count != 4 {
        return text
      }
      match hex_digit(nibble) {
        Some(ch) => sb..write_char(ch)
        None => return text
      }
    }
    sb.to_string()
  } else {
    text
  }
}

///|
pub fn term_to_smt2(term : Term) -> String {
  match term {
    Term::BoolVal(value) => if value { "true" } else { "false" }
    Term::IntVal(value) => "\{value}"
    Term::RealVal(value) => value
    Term::BitVecVal(value) => bitvec_to_smt2(value)
    Term::FpVal(value) =>
      "(fp \{bitvec_to_smt2(value.sign)} \{bitvec_to_smt2(value.exponent)} \{bitvec_to_smt2(value.significand)})"
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
