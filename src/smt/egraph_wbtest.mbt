///|
fn egraph_bool_const(
  manager : @ast.AstManager,
  name : String,
) -> @util.ExprId raise {
  let decl = manager.declare_const(name, manager.bool_sort())
  manager.mk_app(decl, [])
}

///|
fn egraph_context_result_text(result : SmtContextResult) -> String {
  match result {
    SmtContextSat(_) => "sat"
    SmtContextUnsat => "unsat"
    SmtContextUnknown(reason) => "unknown:\{reason}"
  }
}

///|
test "smt_context_egraph_enode_lookup_reuses_and_rolls_back" {
  let manager = @ast.AstManager::new()
  let p = egraph_bool_const(manager, "p")
  let q = egraph_bool_const(manager, "q")
  let context = SmtContext::new(manager)
  inspect(context.mk_enode_text(p), content="enode#0")
  inspect(context.expr2enode_text(p), content="enode#0")
  context.push()
  inspect(context.mk_enode_text(q), content="enode#1")
  context.pop(1)
  inspect(context.expr2enode_text(p), content="enode#0")
  inspect(context.expr2enode_text(q), content="missing")
}

///|
test "smt_internalizer_literal2enode_uses_existing_enode_storage" {
  let manager = @ast.AstManager::new()
  let p = egraph_bool_const(manager, "p")
  let context = SmtContext::new(manager)
  inspect(context.mk_enode_text(p), content="enode#0")
  inspect(context.bool_literal2enode_text(p), content="enode#0")
}

///|
test "smt_egraph_storage_does_not_feed_sat_facts" {
  let manager = @ast.AstManager::new()
  let p = egraph_bool_const(manager, "p")
  let context = SmtContext::new(manager)
  inspect(context.mk_enode_text(p), content="enode#0")
  inspect(context.egraph_new_eq_count(), content="0")
  inspect(context.egraph_new_diseq_count(), content="0")
  inspect(context.root_clause_count(), content="0")
  inspect(egraph_context_result_text(context.check_sat()), content="sat")
  inspect(context.root_clause_count(), content="0")
}
