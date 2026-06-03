///|
test "goal_tracks_formulas_precision_and_decided_states" {
  let manager = @ast.AstManager::new()
  let goal = Goal::new(manager)
  inspect(goal.is_decided_sat(), content="true")
  let false_expr = manager.mk_bool(false)
  goal.add(false_expr)
  inspect(goal.size(), content="1")
  inspect(goal.is_decided_unsat(), content="true")
  goal.set_precision(Under)
  inspect(goal.precision().to_text(), content="under")
  inspect(goal.is_decided_unsat(), content="false")
  goal.set_reason_unknown(@util.ReasonUnknown::unsupported_fragment("seed"))
  inspect(goal.reason_unknown_text(), content="unsupported-fragment(seed)")
}

///|
test "dependency_converter_records_labels_without_goal_storage_exposure" {
  let deps = DependencyConverter::new()
  deps.add_label("a")
  deps.add_label("b")
  inspect(deps.labels_text(), content="a,b")
}

///|
test "goal_tracks_dependency_converter_and_query_requirements" {
  let manager = @ast.AstManager::new()
  let goal = Goal::new(manager)
  goal.dependency_converter().add_label("named-a")
  goal.dependency_converter().add_label("named-b")
  inspect(goal.dependency_converter().labels_text(), content="named-a,named-b")
  inspect(
    "\{goal.requires_model()},\{goal.requires_proof()},\{goal.requires_unsat_core()}",
    content="false,false,false",
  )
  goal.set_requires_model(true)
  goal.set_requires_proof(true)
  goal.set_requires_unsat_core(true)
  inspect(
    "\{goal.requires_model()},\{goal.requires_proof()},\{goal.requires_unsat_core()}",
    content="true,true,true",
  )
}

///|
test "goal_precision_controls_sat_and_unsat_preservation" {
  let manager = @ast.AstManager::new()
  let goal = Goal::new(manager)
  inspect(
    "\{goal.sat_preserved()},\{goal.unsat_preserved()}",
    content="true,true",
  )
  goal.set_precision(Under)
  inspect(
    "\{goal.sat_preserved()},\{goal.unsat_preserved()}",
    content="true,false",
  )
  goal.set_precision(Over)
  inspect(
    "\{goal.sat_preserved()},\{goal.unsat_preserved()}",
    content="false,true",
  )
  goal.set_precision(UnderOver)
  inspect(
    "\{goal.sat_preserved()},\{goal.unsat_preserved()}",
    content="false,false",
  )
}
