///|
pub(all) enum ArithCompareOp {
  Lt
  Le
  Gt
  Ge
} derive(Eq)

///|
#deprecated
#doc(hidden)
pub extend ArithCompareOp with Eq::{not_equal, equal}

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
  IntValue(Int32)
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
#deprecated
#doc(hidden)
pub extend ExprKind with Eq::{not_equal, equal}

///|
pub(all) struct Expr {
  id : @util.ExprId
  kind : ExprKind
  sort : @util.SortId
} derive(Eq)

///|
#deprecated
#doc(hidden)
pub extend Expr with Eq::{not_equal, equal}
