///|
pub(all) struct SortId(Int) derive(Eq, Compare, Hash)

///|
pub fn SortId::new(value : Int) -> SortId {
  SortId(value)
}

///|
pub fn SortId::to_int(self : SortId) -> Int {
  self.0
}

///|
pub impl Show for SortId with fn output(self, logger) {
  logger.write_string("sort#\{self.0}")
}

///|
pub(all) struct FuncDeclId(Int) derive(Eq, Compare, Hash)

///|
pub fn FuncDeclId::new(value : Int) -> FuncDeclId {
  FuncDeclId(value)
}

///|
pub fn FuncDeclId::to_int(self : FuncDeclId) -> Int {
  self.0
}

///|
pub impl Show for FuncDeclId with fn output(self, logger) {
  logger.write_string("decl#\{self.0}")
}

///|
pub(all) struct ExprId(Int) derive(Eq, Compare, Hash)

///|
pub fn ExprId::new(value : Int) -> ExprId {
  ExprId(value)
}

///|
pub fn ExprId::to_int(self : ExprId) -> Int {
  self.0
}

///|
pub impl Show for ExprId with fn output(self, logger) {
  logger.write_string("expr#\{self.0}")
}

///|
pub(all) struct SatVar(Int) derive(Eq, Compare, Hash)

///|
pub fn SatVar::new(value : Int) -> SatVar {
  SatVar(value)
}

///|
pub fn SatVar::to_int(self : SatVar) -> Int {
  self.0
}

///|
pub impl Show for SatVar with fn output(self, logger) {
  logger.write_string("v\{self.0}")
}

///|
pub(all) struct ScopeLevel(Int) derive(Eq, Compare, Hash)

///|
pub fn ScopeLevel::new(value : Int) -> ScopeLevel {
  ScopeLevel(value)
}

///|
pub fn ScopeLevel::to_int(self : ScopeLevel) -> Int {
  self.0
}

///|
pub impl Show for ScopeLevel with fn output(self, logger) {
  logger.write_string("scope#\{self.0}")
}
