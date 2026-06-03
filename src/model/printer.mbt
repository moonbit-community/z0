///|
pub fn ModelValue::format_smt2(self : ModelValue) -> String {
  self.to_text()
}

///|
fn write_universe_cardinality(
  builder : StringBuilder,
  sort_name : String,
  values : Array[ModelValue],
) -> Unit {
  builder.write_string("\n  ;; cardinality constraint for \{sort_name}")
  builder.write_string("\n  (forall ((x \{sort_name})) ")
  if values.length() == 0 {
    builder.write_string("false")
  } else if values.length() == 1 {
    builder.write_string("(= x ")
    builder.write_string(values[0].format_smt2())
    builder.write_char(')')
  } else {
    builder.write_string("(or")
    for value in values {
      builder.write_string(" (= x ")
      builder.write_string(value.format_smt2())
      builder.write_char(')')
    }
    builder.write_char(')')
  }
  builder.write_char(')')
}

///|
pub fn Model::format(self : Model) -> String {
  let universe_entries = self.universe_interps()
  let bool_entries = self.bool_const_interps()
  let value_entries = self.value_const_interps()
  let func_entries = self.function_interps()
  if universe_entries.is_empty() &&
    bool_entries.is_empty() &&
    value_entries.is_empty() &&
    func_entries.is_empty() {
    "()"
  } else {
    let builder = StringBuilder::new()
    builder.write_char('(')
    for universe in universe_entries {
      builder.write_string("\n  ;; universe \{universe.name}:")
      for value in universe.values {
        builder.write_char(' ')
        builder.write_string(value.format_smt2())
      }
      for value in universe.values {
        builder.write_string("\n  (declare-fun ")
        builder.write_string(value.format_smt2())
        builder.write_string(" () ")
        builder.write_string(universe.name)
        builder.write_char(')')
      }
      write_universe_cardinality(builder, universe.name, universe.values)
    }
    for entry in bool_entries {
      builder.write_string("\n  (define-fun \{entry.name} () Bool\n    ")
      if entry.value {
        builder.write_string("true")
      } else {
        builder.write_string("false")
      }
      builder.write_char(')')
    }
    for entry in value_entries {
      builder.write_string(
        "\n  (define-fun \{entry.name} () \{entry.sort_name}\n    ",
      )
      builder.write_string(entry.value.format_smt2())
      builder.write_char(')')
    }
    for entry in func_entries {
      builder.write_char('\n')
      entry.interp.write_definition(builder, "  ")
    }
    builder.write_string("\n)")
    builder.to_string()
  }
}
