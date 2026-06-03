///|
test "scope_push_pop_restores_items" {
  let scoped : ScopedVector[String] = ScopedVector::new()
  scoped.push_item("global")
  scoped.push_scope()
  scoped.push_item("local")
  ignore(scoped.pop_scope(1))
  inspect(scoped.length(), content="1")
  inspect(scoped.items()[0], content="global")
}

///|
test "scope_pop_too_many_reports_diagnostic" {
  let scoped : ScopedVector[String] = ScopedVector::new()
  try {
    scoped.pop_scope(1)
    inspect("missing diagnostic", content="diagnostic")
  } catch {
    @solver_error.SolverError(_) as error =>
      inspect(
        error,
        content="solver: cannot pop 1 scope(s); only 0 scope(s) are active",
      )
    _ => inspect("wrong diagnostic", content="solver")
  }
}
