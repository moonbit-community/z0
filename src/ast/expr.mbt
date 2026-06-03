///|
pub(all) enum ArithCompareOp {
  Lt
  Le
  Gt
  Ge
} derive(Eq)

///|
pub fn ArithCompareOp::symbol(self : ArithCompareOp) -> String {
  match self {
    Lt => "<"
    Le => "<="
    Gt => ">"
    Ge => ">="
  }
}

///|
pub(all) enum ExprKind {
  BoolValue(Bool)
  IntValue(Int)
  App(@util.FuncDeclId, Array[@util.ExprId])
  MacroRef(String)
  Not(@util.ExprId)
  And(Array[@util.ExprId])
  Or(Array[@util.ExprId])
  Implies(@util.ExprId, @util.ExprId)
  Xor(@util.ExprId, @util.ExprId)
  Eq(@util.ExprId, @util.ExprId)
  Distinct(Array[@util.ExprId])
  ArithCompare(ArithCompareOp, @util.ExprId, @util.ExprId)
} derive(Eq)

///|
pub(all) struct Expr {
  id : @util.ExprId
  kind : ExprKind
  sort : @util.SortId
} derive(Eq)
