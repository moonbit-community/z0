///|
pub(all) struct DefinedName {
  name : String
  expr : @util.ExprId
} derive(Eq)

///|
pub struct DefinedNames {
  priv entries : @util.ScopedVector[DefinedName]
}

///|
pub fn DefinedNames::new() -> DefinedNames {
  { entries: @util.ScopedVector::new() }
}

///|
pub fn DefinedNames::insert(
  self : DefinedNames,
  name : String,
  expr : @util.ExprId,
) -> Unit {
  self.entries.push_item({ name, expr })
}

///|
pub fn DefinedNames::lookup(
  self : DefinedNames,
  name : String,
) -> @util.ExprId? {
  for entry in self.entries.items() {
    if entry.name == name {
      return Some(entry.expr)
    }
  }
  None
}

///|
pub fn DefinedNames::push(self : DefinedNames) -> Unit {
  self.entries.push_scope()
}

///|
pub fn DefinedNames::pop(
  self : DefinedNames,
  count : Int,
) -> Unit raise @solver_error.SolverError {
  self.entries.pop_scope(count)
}

///|
pub(all) struct NnfResult {
  result : @util.ExprId
  new_defs : Array[DefinedName]
  new_def_proofs : Array[String]
  result_proof : String?
  aux_decl_visibility : String
} derive(Eq)

///|
pub fn NnfResult::identity(expr : @util.ExprId) -> NnfResult {
  {
    result: expr,
    new_defs: [],
    new_def_proofs: [],
    result_proof: None,
    aux_decl_visibility: "none",
  }
}

///|
pub fn NnfResult::result(self : NnfResult) -> @util.ExprId {
  self.result
}

///|
pub fn NnfResult::new_defs_count(self : NnfResult) -> Int {
  self.new_defs.length()
}
