///|
pub(all) struct MacroExpansion {
  result : @util.ExprId
  proof : String?
  dependency : String?
} derive(Eq)

///|
pub fn MacroExpansion::result(self : MacroExpansion) -> @util.ExprId {
  self.result
}

///|
pub fn MacroExpansion::proof_text(self : MacroExpansion) -> String {
  match self.proof {
    Some(value) => value
    None => "none"
  }
}

///|
pub fn MacroExpansion::dependency_text(self : MacroExpansion) -> String {
  match self.dependency {
    Some(value) => value
    None => "none"
  }
}

///|
pub struct MacroManager {
  priv entries : Array[BoolMacro]
  priv scopes : Array[Int]
}

///|
pub fn MacroManager::new() -> MacroManager {
  { entries: [], scopes: [] }
}

///|
pub fn MacroManager::insert(
  self : MacroManager,
  name : String,
  expr : @util.ExprId,
) -> Unit {
  self.entries.push(BoolMacro::{ name, expr })
}

///|
pub fn MacroManager::lookup(
  self : MacroManager,
  name : String,
) -> @util.ExprId? {
  let mut index = self.entries.length()
  while index > 0 {
    index -= 1
    let entry = self.entries[index]
    if entry.name == name {
      return Some(entry.expr)
    }
  }
  None
}

///|
pub fn MacroManager::push(self : MacroManager) -> Unit {
  self.scopes.push(self.entries.length())
}

///|
pub fn MacroManager::pop(
  self : MacroManager,
  count : Int,
) -> Unit raise @solver_error.SolverError {
  let depth = self.scopes.length()
  if count < 0 {
    raise @solver_error.SolverError("cannot pop a negative number of scopes")
  } else if count > depth {
    raise @solver_error.SolverError(
      "cannot pop \{count} scope(s); only \{depth} scope(s) are active",
    )
  } else if count > 0 {
    let target_depth = depth - count
    self.entries.truncate(self.scopes[target_depth])
    self.scopes.truncate(target_depth)
  }
}

///|
fn MacroManager::commit(
  self : MacroManager,
  count : Int,
) -> Unit raise @solver_error.SolverError {
  let depth = self.scopes.length()
  if count < 0 {
    raise @solver_error.SolverError("cannot commit a negative number of scopes")
  } else if count > depth {
    raise @solver_error.SolverError(
      "cannot commit \{count} scope(s); only \{depth} scope(s) are active",
    )
  } else if count > 0 {
    self.scopes.truncate(depth - count)
  }
}

///|
pub fn MacroManager::reset(self : MacroManager) -> Unit {
  self.entries.truncate(0)
  self.scopes.truncate(0)
}

///|
fn MacroManager::clear(self : MacroManager) -> Unit {
  self.reset()
}

///|
pub fn MacroManager::copy_to(
  self : MacroManager,
  target : MacroManager,
) -> Unit {
  target.clear()
  for entry in self.entries {
    target.insert(entry.name, entry.expr)
  }
}

///|
fn MacroManager::expand_args(
  self : MacroManager,
  manager : AstManager,
  args : Array[@util.ExprId],
) -> Array[@util.ExprId] raise @type_error.TypeError {
  let expanded : Array[@util.ExprId] = []
  for arg in args {
    expanded.push(self.expand_macros(manager, arg).result)
  }
  expanded
}

///|
pub fn MacroManager::expand_macros(
  self : MacroManager,
  manager : AstManager,
  expr_id : @util.ExprId,
) -> MacroExpansion raise @type_error.TypeError {
  let expr = manager.get_expr(expr_id)
  let result = match expr.kind {
    BoolValue(_) | IntValue(_) => expr_id
    MacroRef(name) =>
      match self.lookup(name) {
        None => raise @type_error.TypeError("unknown macro: \{name}", None)
        Some(body) => self.expand_macros(manager, body).result
      }
    App(decl, args) => manager.mk_app(decl, self.expand_args(manager, args))
    Not(inner) => manager.mk_not(self.expand_macros(manager, inner).result)
    And(args) => manager.mk_and(self.expand_args(manager, args))
    Or(args) => manager.mk_or(self.expand_args(manager, args))
    Implies(lhs, rhs) =>
      manager.mk_implies(
        self.expand_macros(manager, lhs).result,
        self.expand_macros(manager, rhs).result,
      )
    Xor(lhs, rhs) =>
      manager.mk_xor(
        self.expand_macros(manager, lhs).result,
        self.expand_macros(manager, rhs).result,
      )
    Eq(lhs, rhs) =>
      manager.mk_eq(
        self.expand_macros(manager, lhs).result,
        self.expand_macros(manager, rhs).result,
      )
    Distinct(args) => manager.mk_distinct(self.expand_args(manager, args))
    ArithCompare(op, lhs, rhs) =>
      manager.mk_arith_compare(
        op,
        self.expand_macros(manager, lhs).result,
        self.expand_macros(manager, rhs).result,
      )
  }
  { result, proof: None, dependency: None }
}
