///|
test "solver_error_formats_with_prefix" {
  let error = @solver_error.SolverError(
    "cannot pop a negative number of scopes",
  )
  inspect(
    error.format(),
    content="solver: cannot pop a negative number of scopes",
  )
}
