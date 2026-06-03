///|
pub struct AstTranslator {
  priv source : AstManager
  priv target : AstManager
}

///|
pub fn AstTranslator::new(
  source : AstManager,
  target : AstManager,
) -> AstTranslator {
  { source, target }
}

///|
pub fn AstTranslator::translate_sort(
  self : AstTranslator,
  sort : @util.SortId,
) -> @util.SortId raise {
  if sort == self.source.bool_sort() {
    self.target.bool_sort()
  } else if sort == self.source.int_sort() {
    self.target.int_sort()
  } else {
    let name = self.source.sort_name(sort)
    match self.target.lookup_sort(name) {
      Some(existing) => existing
      None => self.target.declare_sort(name, 0)
    }
  }
}

///|
pub fn AstTranslator::translate_decl(
  self : AstTranslator,
  decl_id : @util.FuncDeclId,
) -> @util.FuncDeclId raise {
  let decl = self.source.get_decl(decl_id)
  match self.target.lookup_decl(decl.name) {
    Some(existing) => existing
    None => {
      let domain : Array[@util.SortId] = []
      for sort in decl.domain {
        domain.push(self.translate_sort(sort))
      }
      self.target.declare_fun(
        decl.name,
        domain,
        self.translate_sort(decl.range),
      )
    }
  }
}

///|
fn AstTranslator::translate_args(
  self : AstTranslator,
  args : Array[@util.ExprId],
) -> Array[@util.ExprId] raise {
  let translated : Array[@util.ExprId] = []
  for arg in args {
    translated.push(self.translate_expr(arg))
  }
  translated
}

///|
pub fn AstTranslator::translate_expr(
  self : AstTranslator,
  expr_id : @util.ExprId,
) -> @util.ExprId raise {
  let expr = self.source.get_expr(expr_id)
  match expr.kind {
    BoolValue(value) => self.target.mk_bool(value)
    IntValue(value) => self.target.mk_int(value)
    App(decl, args) =>
      self.target.mk_app(self.translate_decl(decl), self.translate_args(args))
    MacroRef(name) => self.target.mk_macro_ref(name)
    Not(inner) => self.target.mk_not(self.translate_expr(inner))
    And(args) => self.target.mk_and(self.translate_args(args))
    Or(args) => self.target.mk_or(self.translate_args(args))
    Implies(lhs, rhs) =>
      self.target.mk_implies(self.translate_expr(lhs), self.translate_expr(rhs))
    Xor(lhs, rhs) =>
      self.target.mk_xor(self.translate_expr(lhs), self.translate_expr(rhs))
    Eq(lhs, rhs) =>
      self.target.mk_eq(self.translate_expr(lhs), self.translate_expr(rhs))
    Distinct(args) => self.target.mk_distinct(self.translate_args(args))
    ArithCompare(op, lhs, rhs) =>
      self.target.mk_arith_compare(
        op,
        self.translate_expr(lhs),
        self.translate_expr(rhs),
      )
  }
}
