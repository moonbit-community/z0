///|
priv struct BoolBinding {
  expr : @util.ExprId
  bool_var : @pure_sat.BoolVar
}

///|
pub struct SmtInternalizer {
  priv manager : @ast.AstManager
  priv sat_core : @pure_sat.SatSolverCore
  priv egraph : @egraph.EGraph
  priv bindings : Array[BoolBinding]
  priv scopes : Array[Int]
}

///|
pub fn SmtInternalizer::new(
  manager : @ast.AstManager,
  sat_core : @pure_sat.SatSolverCore,
  egraph : @egraph.EGraph,
) -> SmtInternalizer {
  { manager, sat_core, egraph, bindings: [], scopes: [] }
}

///|
fn SmtInternalizer::enode_child_exprs(
  self : SmtInternalizer,
  expr : @util.ExprId,
) -> Array[@util.ExprId] {
  match self.manager.get_expr(expr).kind {
    BoolValue(_) | IntValue(_) | MacroRef(_) => []
    App(_, args) | And(args) | Or(args) | Distinct(args) => args.copy()
    Not(inner) => [inner]
    Implies(lhs, rhs)
    | Xor(lhs, rhs)
    | Eq(lhs, rhs)
    | ArithCompare(_, lhs, rhs) => [lhs, rhs]
  }
}

///|
fn SmtInternalizer::enode_operator_key(
  self : SmtInternalizer,
  expr : @util.ExprId,
) -> Int {
  match self.manager.get_expr(expr).kind {
    App(decl, _) => decl.to_int()
    _ => expr.to_int()
  }
}

///|
pub fn SmtInternalizer::mk_enode(
  self : SmtInternalizer,
  expr : @util.ExprId,
) -> @egraph.EnodeId {
  match self.egraph.find(expr) {
    Some(id) => id
    None => {
      let args : Array[@egraph.EnodeId] = []
      for child in self.enode_child_exprs(expr) {
        args.push(self.mk_enode(child))
      }
      self.egraph.mk_enode_with_key(
        expr,
        args,
        0,
        self.enode_operator_key(expr),
      )
    }
  }
}

///|
pub fn SmtInternalizer::expr2enode(
  self : SmtInternalizer,
  expr : @util.ExprId,
) -> @egraph.EnodeId? {
  self.egraph.find(expr)
}

///|
pub fn SmtInternalizer::literal2enode(
  self : SmtInternalizer,
  literal : @pure_sat.Literal,
) -> @egraph.EnodeId? {
  match self.literal2expr(literal) {
    Some(expr) => self.expr2enode(expr)
    None => None
  }
}

///|
pub fn SmtInternalizer::push_scope(self : SmtInternalizer) -> Unit {
  self.scopes.push(self.bindings.length())
}

///|
pub fn SmtInternalizer::pop_scope(self : SmtInternalizer, count : Int) -> Unit {
  if count <= 0 {
    return
  }
  let depth = self.scopes.length()
  if depth == 0 {
    return
  }
  let pop_count = if count > depth { depth } else { count }
  let target_depth = depth - pop_count
  self.bindings.truncate(self.scopes[target_depth])
  self.scopes.truncate(target_depth)
}

///|
fn SmtInternalizer::find_bool_var(
  self : SmtInternalizer,
  expr : @util.ExprId,
) -> @pure_sat.BoolVar? {
  for binding in self.bindings {
    if binding.expr == expr {
      return Some(binding.bool_var)
    }
  }
  None
}

///|
pub fn SmtInternalizer::to_bool_var(
  self : SmtInternalizer,
  expr : @util.ExprId,
) -> @pure_sat.BoolVar raise @type_error.TypeError {
  if self.manager.expr_sort(expr) != self.manager.bool_sort() {
    raise @type_error.TypeError("expected Bool expression", None)
  }
  match self.find_bool_var(expr) {
    Some(bool_var) => bool_var
    None => {
      let bool_var = self.sat_core.add_var()
      self.bindings.push(BoolBinding::{ expr, bool_var })
      bool_var
    }
  }
}

///|
fn SmtInternalizer::add_clause(
  self : SmtInternalizer,
  literals : Array[@pure_sat.Literal],
) -> Unit {
  ignore(self.sat_core.add_clause(@pure_sat.Clause::new(literals)))
}

///|
fn SmtInternalizer::internalize_compound(
  self : SmtInternalizer,
  expr : @util.ExprId,
  define_root : (@pure_sat.Literal) -> Unit raise @type_error.TypeError,
) -> @pure_sat.Literal raise @type_error.TypeError {
  match self.find_bool_var(expr) {
    Some(bool_var) => @pure_sat.Literal::pos(bool_var)
    None => {
      let root = @pure_sat.Literal::pos(self.to_bool_var(expr))
      define_root(root)
      root
    }
  }
}

///|
pub fn SmtInternalizer::internalize_bool(
  self : SmtInternalizer,
  expr : @util.ExprId,
) -> @pure_sat.Literal raise @type_error.TypeError {
  if self.manager.expr_sort(expr) != self.manager.bool_sort() {
    raise @type_error.TypeError("expected Bool expression", None)
  }
  let node = self.manager.get_expr(expr)
  match node.kind {
    BoolValue(value) => {
      let literal = @pure_sat.Literal::pos(self.to_bool_var(expr))
      self.add_clause([if value { literal } else { literal.negate() }])
      literal
    }
    IntValue(_) => raise @type_error.TypeError("expected Bool expression", None)
    App(_, args) =>
      if args.is_empty() {
        @pure_sat.Literal::pos(self.to_bool_var(expr))
      } else {
        raise @type_error.TypeError("non-nullary Bool application", None)
      }
    Not(inner) => self.internalize_bool(inner).negate()
    And(args) =>
      self.internalize_compound(expr, fn(root) raise @type_error.TypeError {
        let defining : Array[@pure_sat.Literal] = [root]
        for arg in args {
          let literal = self.internalize_bool(arg)
          self.add_clause([root.negate(), literal])
          defining.push(literal.negate())
        }
        self.add_clause(defining)
      })
    Or(args) =>
      self.internalize_compound(expr, fn(root) raise @type_error.TypeError {
        let defining : Array[@pure_sat.Literal] = [root.negate()]
        for arg in args {
          let literal = self.internalize_bool(arg)
          self.add_clause([root, literal.negate()])
          defining.push(literal)
        }
        self.add_clause(defining)
      })
    Implies(lhs, rhs) =>
      self.internalize_compound(expr, fn(root) raise @type_error.TypeError {
        let left = self.internalize_bool(lhs)
        let right = self.internalize_bool(rhs)
        self.add_clause([root.negate(), left.negate(), right])
        self.add_clause([root, left])
        self.add_clause([root, right.negate()])
      })
    Xor(lhs, rhs) =>
      self.internalize_compound(expr, fn(root) raise @type_error.TypeError {
        let left = self.internalize_bool(lhs)
        let right = self.internalize_bool(rhs)
        self.add_clause([root.negate(), left, right])
        self.add_clause([root.negate(), left.negate(), right.negate()])
        self.add_clause([root, left.negate(), right])
        self.add_clause([root, left, right.negate()])
      })
    Eq(lhs, rhs) =>
      if self.manager.expr_sort(lhs) == self.manager.bool_sort() &&
        self.manager.expr_sort(rhs) == self.manager.bool_sort() {
        self.internalize_compound(expr, fn(root) raise @type_error.TypeError {
          let left = self.internalize_bool(lhs)
          let right = self.internalize_bool(rhs)
          self.add_clause([root.negate(), left.negate(), right])
          self.add_clause([root.negate(), left, right.negate()])
          self.add_clause([root, left, right])
          self.add_clause([root, left.negate(), right.negate()])
        })
      } else {
        raise @type_error.TypeError("non-Bool equality", None)
      }
    Distinct(args) =>
      match args.length() {
        0 | 1 => self.internalize_bool(self.manager.mk_bool(true))
        2 => self.internalize_bool(self.manager.mk_xor(args[0], args[1]))
        _ => self.internalize_bool(self.manager.mk_bool(false))
      }
    ArithCompare(_, _, _) =>
      raise @type_error.TypeError("arith comparison requires theory", None)
    MacroRef(_) =>
      self.internalize_bool(self.manager.expand_macros(expr).result())
  }
}

///|
pub fn SmtInternalizer::expr2literal(
  self : SmtInternalizer,
  expr : @util.ExprId,
) -> SmtLiteral raise @type_error.TypeError {
  SmtLiteral::new(self.internalize_bool(expr))
}

///|
pub fn SmtInternalizer::literal2expr(
  self : SmtInternalizer,
  literal : @pure_sat.Literal,
) -> @util.ExprId? {
  for binding in self.bindings {
    if binding.bool_var == literal.bool_var() {
      return Some(binding.expr)
    }
  }
  None
}

///|
pub fn SmtInternalizer::sat_var_count(self : SmtInternalizer) -> Int {
  self.bindings.length()
}

///|
pub fn SmtInternalizer::lookup_bool_text(
  self : SmtInternalizer,
  expr : @util.ExprId,
) -> String {
  match self.find_bool_var(expr) {
    Some(bool_var) => "\{@pure_sat.Literal::pos(bool_var)}"
    None => "missing"
  }
}

///|
fn SmtInternalizer::bool_model_entries(
  self : SmtInternalizer,
  model : @pure_sat.SatCoreModel,
) -> Array[SmtBoolModelEntry] {
  let entries : Array[SmtBoolModelEntry] = []
  for binding in self.bindings {
    let expr = self.manager.get_expr(binding.expr)
    match expr.kind {
      App(decl_id, args) =>
        if args.is_empty() && expr.sort == self.manager.bool_sort() {
          match model.value(binding.bool_var) {
            Some(value) => {
              let decl = self.manager.get_decl(decl_id)
              entries.push(SmtBoolModelEntry::{
                decl: decl_id,
                name: decl.name,
                value,
              })
            }
            None => ()
          }
        }
      _ => ()
    }
  }
  entries
}

///|
fn SmtInternalizer::build_model(
  self : SmtInternalizer,
  sat_model : @pure_sat.SatCoreModel,
  theories : Array[@theory_core.TheoryPlugin],
) -> SmtModelBuildResult {
  let builder = SmtModelBuilder::init_model()
  builder.mk_bool_model(self.bool_model_entries(sat_model))
  match builder.mk_euf_value_deps(self.manager, self.egraph, theories) {
    Some(reason) => SmtModelBuildUnknown(reason)
    None => SmtModelBuildSuccess(builder.finalize_model())
  }
}
