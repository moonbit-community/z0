///|
pub fn preprocessing_disabled_factory(
  base : @solver.SolverFactory,
) -> @solver.SolverFactory {
  SolverPreprocess::disabled(base).as_factory()
}
