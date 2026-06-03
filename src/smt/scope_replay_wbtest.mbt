///|
fn scoped_bool_const(
  manager : @ast.AstManager,
  name : String,
) -> @util.ExprId raise {
  let decl = manager.declare_const(name, manager.bool_sort())
  manager.mk_app(decl, [])
}

///|
fn scoped_context_result_text(result : SmtContextResult) -> String {
  match result {
    SmtContextSat(_) => "sat"
    SmtContextUnsat => "unsat"
    SmtContextUnknown(reason) => "unknown:\{reason}"
  }
}

///|
test "smt_context_push_pop_replays_live_root_clauses" {
  let manager = @ast.AstManager::new()
  let p = scoped_bool_const(manager, "p")
  let not_p = manager.mk_not(p)
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  inspect(scoped_context_result_text(context.check_sat()), content="sat")
  let root_count = context.root_clause_count()
  context.push()
  context.assert_expr(not_p)
  inspect(scoped_context_result_text(context.check_sat()), content="unsat")
  inspect(context.root_clause_count() > root_count, content="true")
  context.pop(1)
  inspect(scoped_context_result_text(context.check_sat()), content="sat")
  inspect(context.root_clause_count(), content="\{root_count}")
}

///|
test "smt_context_pre_push_pending_assertions_survive_scoped_check" {
  let manager = @ast.AstManager::new()
  let p = scoped_bool_const(manager, "p")
  let not_p = manager.mk_not(p)
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  context.push()
  inspect(scoped_context_result_text(context.check_sat()), content="sat")
  context.pop(1)
  context.assert_expr(not_p)
  inspect(scoped_context_result_text(context.check_sat()), content="unsat")
}

///|
test "smt_internalizer_cache_reuses_outer_literals_and_drops_popped_literals" {
  let manager = @ast.AstManager::new()
  let p = scoped_bool_const(manager, "p")
  let q = scoped_bool_const(manager, "q")
  let context = SmtContext::new(manager)
  inspect(context.internalize_bool_text(p), content="b1")
  context.push()
  inspect(context.internalize_bool_text(q), content="b3")
  context.pop(1)
  inspect(context.lookup_bool_text(p), content="b1")
  inspect(context.lookup_bool_text(q), content="missing")
}

///|
test "smt_context_mutation_marks_model_cache_stale" {
  let manager = @ast.AstManager::new()
  let p = scoped_bool_const(manager, "p")
  let q = scoped_bool_const(manager, "q")
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  inspect(scoped_context_result_text(context.check_sat()), content="sat")
  inspect(context.cache_state_text(), content="model=current")
  context.assert_expr(q)
  inspect(context.cache_state_text(), content="model=stale")
}
