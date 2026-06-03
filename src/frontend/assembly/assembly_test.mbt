///|
fn bool_const(manager : @ast.AstManager, name : String) -> @util.ExprId raise {
  let decl = manager.declare_const(name, manager.bool_sort())
  manager.mk_app(decl, [])
}

///|
fn unit_availability_text(value : @util.Availability[Unit]) -> String {
  match value {
    @util.Available(_) => "available"
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
test "frontend_assembly_default_solver_factory_solves_bool_sat" {
  let manager = @ast.AstManager::new()
  let p = bool_const(manager, "p")
  let solver = solver_factory().create(
    manager,
    @solver.SolverFactoryConfig::new().with_logic("QF_UF"),
  )
  inspect(unit_availability_text(solver.assert_expr(p)), content="available")
  inspect(solver.check_sat().to_text(), content="sat")
}
