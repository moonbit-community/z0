///|
fn bool_value(manager : @ast.AstManager, expr : @util.ExprId) -> Bool? {
  match manager.get_expr(expr).kind {
    BoolValue(value) => Some(value)
    _ => None
  }
}

///|
fn int_value(manager : @ast.AstManager, expr : @util.ExprId) -> Int? {
  match manager.get_expr(expr).kind {
    IntValue(value) => Some(value)
    _ => None
  }
}

///|
fn eval_compare(op : @ast.ArithCompareOp, lhs : Int, rhs : Int) -> Bool {
  match op {
    Lt => lhs < rhs
    Le => lhs <= rhs
    Gt => lhs > rhs
    Ge => lhs >= rhs
  }
}

///|
fn rewrite_args(
  manager : @ast.AstManager,
  args : Array[@util.ExprId],
) -> Array[@util.ExprId] raise @type_error.TypeError {
  let rewritten : Array[@util.ExprId] = []
  for arg in args {
    rewritten.push(rewrite_bool(manager, arg))
  }
  rewritten
}

///|
fn has_duplicate(args : Array[@util.ExprId]) -> Bool {
  for i in 0..<args.length() {
    for j in (i + 1)..<args.length() {
      if args[i] == args[j] {
        return true
      }
    }
  }
  false
}

///|
fn all_bool(manager : @ast.AstManager, args : Array[@util.ExprId]) -> Bool {
  for arg in args {
    if manager.expr_sort(arg) != manager.bool_sort() {
      return false
    }
  }
  true
}

///|
fn rewrite_not(
  manager : @ast.AstManager,
  inner : @util.ExprId,
) -> @util.ExprId raise @type_error.TypeError {
  match bool_value(manager, inner) {
    Some(true) => manager.mk_bool(false)
    Some(false) => manager.mk_bool(true)
    None => manager.mk_not(inner)
  }
}

///|
fn rewrite_and(
  manager : @ast.AstManager,
  args : Array[@util.ExprId],
) -> @util.ExprId raise @type_error.TypeError {
  let kept : Array[@util.ExprId] = []
  for arg in args {
    match bool_value(manager, arg) {
      Some(false) => return manager.mk_bool(false)
      Some(true) => ()
      None => kept.push(arg)
    }
  }
  match kept.length() {
    0 => manager.mk_bool(true)
    1 => kept[0]
    _ => manager.mk_and(kept)
  }
}

///|
fn rewrite_or(
  manager : @ast.AstManager,
  args : Array[@util.ExprId],
) -> @util.ExprId raise @type_error.TypeError {
  let kept : Array[@util.ExprId] = []
  for arg in args {
    match bool_value(manager, arg) {
      Some(true) => return manager.mk_bool(true)
      Some(false) => ()
      None => kept.push(arg)
    }
  }
  match kept.length() {
    0 => manager.mk_bool(false)
    1 => kept[0]
    _ => manager.mk_or(kept)
  }
}

///|
fn rewrite_xor(
  manager : @ast.AstManager,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> @util.ExprId raise @type_error.TypeError {
  match (bool_value(manager, lhs), bool_value(manager, rhs)) {
    (Some(a), Some(b)) => manager.mk_bool(a != b)
    (Some(true), None) => rewrite_not(manager, rhs)
    (Some(false), None) => rhs
    (None, Some(true)) => rewrite_not(manager, lhs)
    (None, Some(false)) => lhs
    (None, None) => manager.mk_xor(lhs, rhs)
  }
}

///|
fn rewrite_distinct(
  manager : @ast.AstManager,
  args : Array[@util.ExprId],
) -> @util.ExprId raise @type_error.TypeError {
  if args.length() <= 1 {
    manager.mk_bool(true)
  } else if has_duplicate(args) {
    manager.mk_bool(false)
  } else if args.length() == 2 {
    rewrite_not(manager, manager.mk_eq(args[0], args[1]))
  } else if all_bool(manager, args) {
    manager.mk_bool(false)
  } else {
    manager.mk_distinct(args)
  }
}

///|
fn rewrite_arith_compare(
  manager : @ast.AstManager,
  op : @ast.ArithCompareOp,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> @util.ExprId raise @type_error.TypeError {
  match (int_value(manager, lhs), int_value(manager, rhs)) {
    (Some(a), Some(b)) => manager.mk_bool(eval_compare(op, a, b))
    _ => manager.mk_arith_compare(op, lhs, rhs)
  }
}

///|
pub fn rewrite_bool(
  manager : @ast.AstManager,
  expr_id : @util.ExprId,
) -> @util.ExprId raise @type_error.TypeError {
  let expr = manager.get_expr(expr_id)
  match expr.kind {
    BoolValue(_) | IntValue(_) | App(_, _) | MacroRef(_) => expr_id
    Not(inner) => rewrite_not(manager, rewrite_bool(manager, inner))
    And(args) => rewrite_and(manager, rewrite_args(manager, args))
    Or(args) => rewrite_or(manager, rewrite_args(manager, args))
    Implies(lhs, rhs) =>
      rewrite_or(manager, [
        manager.mk_not(rewrite_bool(manager, lhs)),
        rewrite_bool(manager, rhs),
      ])
    Xor(lhs, rhs) =>
      rewrite_xor(
        manager,
        rewrite_bool(manager, lhs),
        rewrite_bool(manager, rhs),
      )
    Eq(lhs, rhs) => {
      let lhs_rewritten = rewrite_bool(manager, lhs)
      let rhs_rewritten = rewrite_bool(manager, rhs)
      if lhs_rewritten == rhs_rewritten {
        manager.mk_bool(true)
      } else {
        manager.mk_eq(lhs_rewritten, rhs_rewritten)
      }
    }
    Distinct(args) => rewrite_distinct(manager, rewrite_args(manager, args))
    ArithCompare(op, lhs, rhs) =>
      rewrite_arith_compare(
        manager,
        op,
        rewrite_bool(manager, lhs),
        rewrite_bool(manager, rhs),
      )
  }
}

///|
pub fn rewrite_bool_result(
  manager : @ast.AstManager,
  expr_id : @util.ExprId,
) -> RewriteResult raise @type_error.TypeError {
  {
    result: rewrite_bool(manager, expr_id),
    proof: None,
    dependency: None,
    unsupported: None,
  }
}
