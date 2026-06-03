///|
pub struct EufModelObligations {
  priv values : Array[@theory_core.TheoryTermRef]
  priv functions : Array[@util.FuncDeclId]
}

///|
pub fn EufModelObligations::new() -> EufModelObligations {
  { values: [], functions: [] }
}

///|
pub fn EufModelObligations::add_uninterpreted_value(
  self : EufModelObligations,
  term : @theory_core.TheoryTermRef,
) -> Unit {
  self.values.push(term)
}

///|
pub fn EufModelObligations::add_function_obligation(
  self : EufModelObligations,
  decl : @util.FuncDeclId,
) -> Unit {
  self.functions.push(decl)
}

///|
pub fn EufModelObligations::summary_text(self : EufModelObligations) -> String {
  "values=\{self.values.length()},functions=\{self.functions.length()}"
}
