///|
fn theory_plugin_by_id(
  theories : Array[@theory_core.TheoryPlugin],
  owner : @theory_ids.TheoryId,
) -> @theory_core.TheoryPlugin? {
  for theory in theories {
    if theory.id() == owner {
      return Some(theory)
    }
  }
  None
}

///|
fn materialize_theory_antecedent(
  theories : Array[@theory_core.TheoryPlugin],
  antecedent : @theory_core.AntecedentId,
) -> Array[@pure_sat.Literal] {
  match theory_plugin_by_id(theories, antecedent.owner()) {
    Some(theory) => theory.get_antecedents(antecedent)
    None => []
  }
}
