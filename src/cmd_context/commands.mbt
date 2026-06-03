///|
pub struct ModelQueryTerm {
  priv display : String
  priv expr : @util.ExprId
} derive(Eq)

///|
pub fn ModelQueryTerm::new(
  display : String,
  expr : @util.ExprId,
) -> ModelQueryTerm {
  { display, expr }
}

///|
pub fn ModelQueryTerm::display(self : ModelQueryTerm) -> String {
  self.display
}

///|
pub fn ModelQueryTerm::expr(self : ModelQueryTerm) -> @util.ExprId {
  self.expr
}

///|
pub(all) enum Command {
  SetLogic(String)
  SetOption(String, String)
  SetInfo(String, String)
  GetOption(String)
  DeclareSort(String, Int)
  DeclareConst(String, @util.SortId)
  DeclareFun(String, Array[@util.SortId], @util.SortId)
  DefineFun(String, Array[(String, @util.SortId)], @util.SortId, @util.ExprId)
  Assert(@util.ExprId)
  AssertNamed(@util.ExprId, String)
  Push(Int)
  Pop(Int)
  Reset
  ResetAssertions
  CheckSat
  CheckSatAssuming(Array[@util.ExprId])
  GetModel
  GetValue(Array[ModelQueryTerm])
  Eval(ModelQueryTerm, Bool)
  GetProof
  GetUnsatCore
  GetUnsatAssumptions
  GetInfo(String)
  Echo(String)
  Exit
} derive(Eq)

///|
fn sort_list_repr(sorts : Array[@util.SortId]) -> String {
  let builder = StringBuilder::new()
  builder.write_char('[')
  for i in 0..<sorts.length() {
    if i > 0 {
      builder.write_string(", ")
    }
    builder.write_object(sorts[i])
  }
  builder.write_char(']')
  builder.to_string()
}

///|
pub impl Show for Command with fn output(self, logger) {
  match self {
    SetLogic(logic) => logger.write_string("SetLogic(\{logic})")
    SetOption(name, value) =>
      logger.write_string("SetOption(\{name}, \{value})")
    SetInfo(name, value) => logger.write_string("SetInfo(\{name}, \{value})")
    GetOption(name) => logger.write_string("GetOption(\{name})")
    DeclareSort(name, arity) =>
      logger.write_string("DeclareSort(\{name}, \{arity})")
    DeclareConst(name, sort) =>
      logger.write_string("DeclareConst(\{name}, \{sort})")
    DeclareFun(name, domain, range) =>
      logger.write_string(
        "DeclareFun(\{name}, \{sort_list_repr(domain)}, \{range})",
      )
    DefineFun(name, params, range, body) =>
      logger.write_string(
        "DefineFun(\{name}, \{params.length()} params, \{range}, \{body})",
      )
    Assert(expr) => logger.write_string("Assert(\{expr})")
    AssertNamed(expr, name) =>
      logger.write_string("AssertNamed(\{expr}, \{name})")
    Push(count) => logger.write_string("Push(\{count})")
    Pop(count) => logger.write_string("Pop(\{count})")
    Reset => logger.write_string("Reset")
    ResetAssertions => logger.write_string("ResetAssertions")
    CheckSat => logger.write_string("CheckSat")
    CheckSatAssuming(assumptions) =>
      logger.write_string("CheckSatAssuming(\{assumptions.length()})")
    GetModel => logger.write_string("GetModel")
    GetValue(terms) => logger.write_string("GetValue(\{terms.length()})")
    Eval(_, completion) => logger.write_string("Eval(\{completion})")
    GetProof => logger.write_string("GetProof")
    GetUnsatCore => logger.write_string("GetUnsatCore")
    GetUnsatAssumptions => logger.write_string("GetUnsatAssumptions")
    GetInfo(name) => logger.write_string("GetInfo(\{name})")
    Echo(value) => logger.write_string("Echo(\{value})")
    Exit => logger.write_string("Exit")
  }
}
