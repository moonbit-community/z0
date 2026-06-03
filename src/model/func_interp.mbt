///|
struct FuncInterpEntry {
  args : Array[String]
  value : String
}

///|
pub struct FuncInterp {
  priv name : String
  priv domain : Array[String]
  priv range : String
  priv entries : Array[FuncInterpEntry]
  priv mut else_value : String?
}

///|
pub fn FuncInterp::new(
  name : String,
  domain : Array[String],
  range : String,
) -> FuncInterp {
  { name, domain: domain.copy(), range, entries: [], else_value: None }
}

///|
fn func_interp_args_equal(lhs : Array[String], rhs : Array[String]) -> Bool {
  if lhs.length() != rhs.length() {
    false
  } else {
    for i in 0..<lhs.length() {
      if lhs[i] != rhs[i] {
        return false
      }
    }
    true
  }
}

///|
pub fn FuncInterp::add_entry(
  self : FuncInterp,
  args : Array[String],
  value : String,
) -> Unit {
  for i, entry in self.entries {
    if func_interp_args_equal(entry.args, args) {
      self.entries[i] = { args: args.copy(), value }
      return
    }
  }
  self.entries.push({ args: args.copy(), value })
}

///|
pub fn FuncInterp::set_else(self : FuncInterp, value : String) -> Unit {
  self.else_value = Some(value)
}

///|
fn FuncInterp::has_display_name(self : FuncInterp) -> Bool {
  self.name != ""
}

///|
fn FuncInterpEntry::matches(
  self : FuncInterpEntry,
  args : Array[ModelValue],
) -> Bool {
  if self.args.length() != args.length() {
    false
  } else {
    for i in 0..<args.length() {
      if self.args[i] != args[i].to_text() {
        return false
      }
    }
    true
  }
}

///|
fn FuncInterp::evaluate(
  self : FuncInterp,
  args : Array[ModelValue],
) -> ModelValue? {
  for entry in self.ordered_entries() {
    if entry.matches(args) {
      return Some(ModelValue::raw(entry.value))
    }
  }
  match self.else_value {
    Some(value) => Some(ModelValue::raw(value))
    None => None
  }
}

///|
fn compare_func_interp_entry(
  lhs : FuncInterpEntry,
  rhs : FuncInterpEntry,
) -> Int {
  lhs.args.join("\u{0}").compare(rhs.args.join("\u{0}"))
}

///|
fn FuncInterp::ordered_entries(self : FuncInterp) -> Array[FuncInterpEntry] {
  let entries = self.entries.copy()
  entries.sort_by(compare_func_interp_entry)
  entries
}

///|
fn FuncInterp::binder_text(self : FuncInterp) -> String {
  let binders : Array[String] = []
  for i, sort in self.domain {
    binders.push("(x\{i} \{sort})")
  }
  binders.join(" ")
}

///|
fn FuncInterp::entry_condition(entry : FuncInterpEntry) -> String {
  if entry.args.length() == 1 {
    "(= x0 \{entry.args[0]})"
  } else {
    let parts : Array[String] = []
    for i, arg in entry.args {
      parts.push("(= x\{i} \{arg})")
    }
    "(and \{parts.join(" ")})"
  }
}

///|
fn FuncInterp::else_text(self : FuncInterp) -> String {
  match self.else_value {
    Some(value) => value
    None => "#unspecified"
  }
}

///|
fn FuncInterp::write_entries(
  _self : FuncInterp,
  builder : StringBuilder,
  entries : Array[FuncInterpEntry],
  index : Int,
  fallback : String,
  base_indent : String,
) -> Unit {
  if index >= entries.length() {
    builder.write_string(fallback)
  } else {
    let entry = entries[index]
    let indent = base_indent + "  ".repeat(index + 1)
    builder.write_string(
      "(ite \{FuncInterp::entry_condition(entry)}\n\{indent}  \{entry.value}\n\{indent}  ",
    )
    _self.write_entries(builder, entries, index + 1, fallback, base_indent)
    builder.write_char(')')
  }
}

///|
fn FuncInterp::write_definition(
  self : FuncInterp,
  builder : StringBuilder,
  base_indent : String,
) -> Unit {
  builder.write_string(
    "\{base_indent}(define-fun \{self.name} (\{self.binder_text()}) \{self.range}\n\{base_indent}  ",
  )
  self.write_entries(
    builder,
    self.ordered_entries(),
    0,
    self.else_text(),
    base_indent,
  )
  builder.write_char(')')
}

///|
pub fn FuncInterp::format(self : FuncInterp) -> String {
  let builder = StringBuilder::new()
  self.write_definition(builder, "")
  builder.to_string()
}
