///|
pub enum Command {
  SetLogic(String)
  SetOption(String, SExpr)
  SetInfo(String, SExpr)
  DeclareSort(String, Int)
  DefineSort(String, Array[String], Sort)
  DeclareConst(String, Sort)
  DeclareFun(String, Array[Sort], Sort)
  DefineFun(String, Array[BoundVar], Sort, Term)
  Assert(Term)
  Simplify(SExpr, Array[SExpr])
  Push(Int)
  Pop(Int)
  CheckSat
  CheckSatUsing(String)
  GetValue(Array[Term])
  GetModel
  Exit
  Unsupported(SExpr)
} derive(Show, ToJson, Eq)

///|
pub struct Script {
  commands : Array[Command]
} derive(Show, ToJson, Eq)
