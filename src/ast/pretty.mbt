///|
fn write_expr_list(
  manager : AstManager,
  builder : StringBuilder,
  op : String,
  args : Array[@util.ExprId],
) -> Unit {
  builder.write_char('(')
  builder.write_string(op)
  for arg in args {
    builder.write_char(' ')
    builder.write_string(manager.pretty(arg))
  }
  builder.write_char(')')
}

///|
pub fn AstManager::pretty(self : AstManager, expr_id : @util.ExprId) -> String {
  let expr = self.get_expr(expr_id)
  match expr.kind {
    BoolValue(true) => "true"
    BoolValue(false) => "false"
    IntValue(value) => value.to_string()
    MacroRef(name) => name
    App(decl_id, args) => {
      let decl = self.get_decl(decl_id)
      if args.is_empty() {
        decl.name
      } else {
        let builder = StringBuilder::new()
        write_expr_list(self, builder, decl.name, args)
        builder.to_string()
      }
    }
    Not(inner) => "(not \{self.pretty(inner)})"
    And(args) => {
      let builder = StringBuilder::new()
      write_expr_list(self, builder, "and", args)
      builder.to_string()
    }
    Or(args) => {
      let builder = StringBuilder::new()
      write_expr_list(self, builder, "or", args)
      builder.to_string()
    }
    Implies(lhs, rhs) => "(=> \{self.pretty(lhs)} \{self.pretty(rhs)})"
    Xor(lhs, rhs) => "(xor \{self.pretty(lhs)} \{self.pretty(rhs)})"
    Eq(lhs, rhs) => "(= \{self.pretty(lhs)} \{self.pretty(rhs)})"
    Distinct(args) => {
      let builder = StringBuilder::new()
      write_expr_list(self, builder, "distinct", args)
      builder.to_string()
    }
    ArithCompare(op, lhs, rhs) =>
      "(\{op.symbol()} \{self.pretty(lhs)} \{self.pretty(rhs)})"
  }
}
