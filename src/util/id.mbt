///|
pub(all) struct SortId(Int32) derive(Eq, Compare, Hash)

///|
pub fn SortId::new(value : Int32) -> SortId {
  SortId(value)
}

///|
pub fn SortId::to_int(self : SortId) -> Int32 {
  self.0
}

///|
pub impl Show for SortId with fn output(self, logger) {
  logger.write_string("sort#\{self.0}")
}

///|
pub(all) struct FuncDeclId(Int32) derive(Eq, Compare, Hash)

///|
pub fn FuncDeclId::new(value : Int32) -> FuncDeclId {
  FuncDeclId(value)
}

///|
pub fn FuncDeclId::to_int(self : FuncDeclId) -> Int32 {
  self.0
}

///|
pub impl Show for FuncDeclId with fn output(self, logger) {
  logger.write_string("decl#\{self.0}")
}

///|
pub(all) struct ExprId(Int32) derive(Eq, Compare, Hash)

///|
pub fn ExprId::new(value : Int32) -> ExprId {
  ExprId(value)
}

///|
pub fn ExprId::to_int(self : ExprId) -> Int32 {
  self.0
}

///|
pub impl Show for ExprId with fn output(self, logger) {
  logger.write_string("expr#\{self.0}")
}

///|
pub(all) struct SatVar(Int32) derive(Eq, Compare, Hash)

///|
pub fn SatVar::new(value : Int32) -> SatVar {
  SatVar(value)
}

///|
pub fn SatVar::to_int(self : SatVar) -> Int32 {
  self.0
}

///|
pub impl Show for SatVar with fn output(self, logger) {
  logger.write_string("v\{self.0}")
}

///|
pub(all) struct ScopeLevel(Int32) derive(Eq, Compare, Hash)

///|
pub fn ScopeLevel::new(value : Int32) -> ScopeLevel {
  ScopeLevel(value)
}

///|
pub fn ScopeLevel::to_int(self : ScopeLevel) -> Int32 {
  self.0
}

///|
pub impl Show for ScopeLevel with fn output(self, logger) {
  logger.write_string("scope#\{self.0}")
}
