///|
fn expand_args(
  manager : @ast.AstManager,
  args : Array[@util.ExprId],
) -> Array[@util.ExprId] raise @type_error.TypeError {
  let expanded : Array[@util.ExprId] = []
  for arg in args {
    expanded.push(expand_macros(manager, arg))
  }
  expanded
}

///|
pub fn expand_macros(
  manager : @ast.AstManager,
  expr_id : @util.ExprId,
) -> @util.ExprId raise @type_error.TypeError {
  let expr = manager.get_expr(expr_id)
  match expr.kind {
    BoolValue(_) | IntValue(_) => expr_id
    MacroRef(name) =>
      match manager.lookup_macro(name) {
        None => raise @type_error.TypeError("unknown macro: \{name}", None)
        Some(body) => expand_macros(manager, body)
      }
    App(decl, args) => manager.mk_app(decl, expand_args(manager, args))
    Not(inner) => manager.mk_not(expand_macros(manager, inner))
    And(args) => manager.mk_and(expand_args(manager, args))
    Or(args) => manager.mk_or(expand_args(manager, args))
    Implies(lhs, rhs) =>
      manager.mk_implies(
        expand_macros(manager, lhs),
        expand_macros(manager, rhs),
      )
    Xor(lhs, rhs) =>
      manager.mk_xor(expand_macros(manager, lhs), expand_macros(manager, rhs))
    Eq(lhs, rhs) =>
      manager.mk_eq(expand_macros(manager, lhs), expand_macros(manager, rhs))
    Distinct(args) => manager.mk_distinct(expand_args(manager, args))
    ArithCompare(op, lhs, rhs) =>
      manager.mk_arith_compare(
        op,
        expand_macros(manager, lhs),
        expand_macros(manager, rhs),
      )
  }
}
