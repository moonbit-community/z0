///|
pub(all) struct FuncDecl {
  id : @util.FuncDeclId
  name : String
  domain : Array[@util.SortId]
  range : @util.SortId
  family : FamilyId
} derive(Eq)

///|
#deprecated
#doc(hidden)
pub extend FuncDecl with Eq::{not_equal, equal}

///|
pub(all) struct BoolMacro {
  name : String
  expr : @util.ExprId
} derive(Eq)

///|
#deprecated
#doc(hidden)
pub extend BoolMacro with Eq::{not_equal, equal}
