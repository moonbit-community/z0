///|
pub fn Model::bool_const_value(self : Model, decl : @util.FuncDeclId) -> Bool? {
  for entry in self.bool_const_interps() {
    if entry.decl == decl {
      return Some(entry.value)
    }
  }
  None
}

///|
fn ModelValue::as_bool(self : ModelValue) -> Bool? {
  match self.to_text() {
    "true" => Some(true)
    "false" => Some(false)
    _ => None
  }
}

///|
fn ModelValue::same_value(self : ModelValue, other : ModelValue) -> Bool {
  self.to_text() == other.to_text()
}

///|
fn bool_model_value(value : Bool) -> ModelValue {
  ModelValue::bool(value)
}

///|
fn int_model_value(value : Int) -> ModelValue {
  ModelValue::int(value)
}

///|
fn compare_int_values(op : @ast.ArithCompareOp, lhs : Int, rhs : Int) -> Bool {
  match op {
    Lt => lhs < rhs
    Le => lhs <= rhs
    Gt => lhs > rhs
    Ge => lhs >= rhs
  }
}

///|
fn Model::eval_bool_args(
  self : Model,
  manager : @ast.AstManager,
  args : Array[@util.ExprId],
  completion : Bool,
) -> Array[Bool]? {
  let values : Array[Bool] = []
  for arg in args {
    match self.eval(manager, arg, completion~) {
      Some(value) =>
        match value.as_bool() {
          Some(bool_value) => values.push(bool_value)
          None => return None
        }
      None => return None
    }
  }
  Some(values)
}

///|
fn all_true(values : Array[Bool]) -> Bool {
  for value in values {
    if !value {
      return false
    }
  }
  true
}

///|
fn any_true(values : Array[Bool]) -> Bool {
  for value in values {
    if value {
      return true
    }
  }
  false
}

///|
fn all_distinct(values : Array[ModelValue]) -> Bool {
  for i in 0..<values.length() {
    for j in (i + 1)..<values.length() {
      if values[i].same_value(values[j]) {
        return false
      }
    }
  }
  true
}

///|
fn Model::eval_values(
  self : Model,
  manager : @ast.AstManager,
  args : Array[@util.ExprId],
  completion : Bool,
) -> Array[ModelValue]? {
  let values : Array[ModelValue] = []
  for arg in args {
    match self.eval(manager, arg, completion~) {
      Some(value) => values.push(value)
      None => return None
    }
  }
  Some(values)
}

///|
fn Model::complete_func_app(
  self : Model,
  manager : @ast.AstManager,
  decl : @util.FuncDeclId,
  args : Array[ModelValue],
) -> ModelValue? {
  let info = manager.get_decl(decl)
  if info.range == manager.bool_sort() {
    None
  } else {
    let range_name = manager.sort_name(info.range)
    let value = self.fresh_uninterpreted_value(info.range, range_name)
    let arg_texts : Array[String] = []
    for arg in args {
      arg_texts.push(arg.to_text())
    }
    match self.func_interp_value(decl) {
      Some(interp) => interp.add_entry(arg_texts, value.to_text())
      None => {
        let domain_names : Array[String] = []
        for sort in info.domain {
          domain_names.push(manager.sort_name(sort))
        }
        let interp = FuncInterp::new(info.name, domain_names, range_name)
        interp.add_entry(arg_texts, value.to_text())
        self.add_func_interp(decl, interp)
      }
    }
    Some(value)
  }
}

///|
fn model_value_for_decl_range(
  manager : @ast.AstManager,
  decl : @util.FuncDeclId,
  value : ModelValue,
) -> ModelValue {
  let info = manager.get_decl(decl)
  if info.range == manager.bool_sort() ||
    value.sort() is Some(_) ||
    manager.sort_name(info.range) == "Int" {
    value
  } else {
    ModelValue::uninterpreted(info.range, value.to_text())
  }
}

///|
pub fn Model::eval(
  self : Model,
  manager : @ast.AstManager,
  expr : @util.ExprId,
  completion~ : Bool,
) -> ModelValue? {
  match manager.get_expr(expr).kind {
    BoolValue(value) => Some(bool_model_value(value))
    IntValue(value) => Some(int_model_value(value))
    App(decl, args) =>
      if args.is_empty() {
        match self.bool_const_value(decl) {
          Some(value) => Some(bool_model_value(value))
          None => {
            let info = manager.get_decl(decl)
            match self.value_const_value(decl) {
              Some(value) => Some(value)
              None =>
                if completion && info.range != manager.bool_sort() {
                  Some(
                    self.complete_value_const(
                      decl,
                      info.name,
                      info.range,
                      manager.sort_name(info.range),
                    ),
                  )
                } else {
                  None
                }
            }
          }
        }
      } else {
        match self.func_interp_value(decl) {
          Some(interp) =>
            match self.eval_values(manager, args, completion) {
              Some(values) =>
                match interp.evaluate(values) {
                  Some(value) =>
                    Some(model_value_for_decl_range(manager, decl, value))
                  None =>
                    if completion {
                      self.complete_func_app(manager, decl, values)
                    } else {
                      None
                    }
                }
              None => None
            }
          None =>
            if completion {
              match self.eval_values(manager, args, completion) {
                Some(values) => self.complete_func_app(manager, decl, values)
                None => None
              }
            } else {
              None
            }
        }
      }
    MacroRef(_) => {
      let expanded = manager.expand_macros(expr) catch { _ => return None }
      self.eval(manager, expanded.result(), completion~)
    }
    Not(inner) =>
      match self.eval(manager, inner, completion~) {
        Some(value) =>
          match value.as_bool() {
            Some(bool_value) => Some(bool_model_value(!bool_value))
            None => None
          }
        None => None
      }
    And(args) =>
      match self.eval_bool_args(manager, args, completion) {
        Some(values) => Some(bool_model_value(all_true(values)))
        None => None
      }
    Or(args) =>
      match self.eval_bool_args(manager, args, completion) {
        Some(values) => Some(bool_model_value(any_true(values)))
        None => None
      }
    Implies(lhs, rhs) =>
      match self.eval_bool_args(manager, [lhs, rhs], completion) {
        Some(values) => Some(bool_model_value(!values[0] || values[1]))
        None => None
      }
    Xor(lhs, rhs) =>
      match self.eval_bool_args(manager, [lhs, rhs], completion) {
        Some(values) => Some(bool_model_value(values[0] != values[1]))
        None => None
      }
    Eq(lhs, rhs) =>
      match self.eval_values(manager, [lhs, rhs], completion) {
        Some(values) => Some(bool_model_value(values[0].same_value(values[1])))
        None => None
      }
    Distinct(args) =>
      match self.eval_values(manager, args, completion) {
        Some(values) => Some(bool_model_value(all_distinct(values)))
        None => None
      }
    ArithCompare(op, lhs, rhs) =>
      match self.eval_values(manager, [lhs, rhs], completion) {
        Some(values) =>
          match (values[0].as_int(), values[1].as_int()) {
            (Some(left), Some(right)) =>
              Some(bool_model_value(compare_int_values(op, left, right)))
            _ => None
          }
        None => None
      }
  }
}
