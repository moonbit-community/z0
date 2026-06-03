///|
pub(all) struct FuncDecl {
  id : @util.FuncDeclId
  name : String
  domain : Array[@util.SortId]
  range : @util.SortId
  family : FamilyId
} derive(Eq)

///|
pub(all) struct BoolMacro {
  name : String
  expr : @util.ExprId
} derive(Eq)
