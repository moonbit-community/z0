///|
test "egraph_dispatch_drains_eq_facts_to_matching_theories_once" {
  let graph = @egraph.EGraph::new()
  let lhs = graph.mk_enode(@util.ExprId::new(1), [], 0)
  let rhs = graph.mk_enode(@util.ExprId::new(2), [], 0)
  let th_a = @theory_ids.TheoryId::new(10)
  let th_b = @theory_ids.TheoryId::new(11)
  graph.attach_theory_var(lhs, th_a, @theory_ids.TheoryVar::new(1))
  graph.attach_theory_var(rhs, th_a, @theory_ids.TheoryVar::new(2))
  graph.attach_theory_var(lhs, th_b, @theory_ids.TheoryVar::new(3))
  graph.attach_theory_var(rhs, th_b, @theory_ids.TheoryVar::new(4))
  graph.enqueue_new_eq(lhs, rhs)
  let log : Array[String] = []
  let plugin_a = @theory_core.TheoryPlugin::default_unimplemented(th_a, "a", [])
  plugin_a.set_new_eq(fn(_, _, fact) {
    log.push("eq:\{fact.owner()}:\{fact.to_int()}")
  })
  let plugin_b = @theory_core.TheoryPlugin::default_unimplemented(th_b, "b", [])
  plugin_b.set_new_eq(fn(_, _, fact) {
    log.push("eq:\{fact.owner()}:\{fact.to_int()}")
  })
  let dispatch = EGraphDispatchState::new()
  dispatch.drain_new_facts(
    graph,
    [plugin_a, plugin_b],
    @theory_core.TheoryContextView::new(scope_depth=0),
    fn(_) { @theory_core.TheoryActions::noop() },
  )
  dispatch.drain_new_facts(
    graph,
    [plugin_a, plugin_b],
    @theory_core.TheoryContextView::new(scope_depth=0),
    fn(_) { @theory_core.TheoryActions::noop() },
  )
  inspect(log.join(">"), content="eq:th#10:0>eq:th#11:1")
  inspect(dispatch.eq_fact_count(), content="2")
}

///|
test "egraph_dispatch_scopes_fact_store_and_diseq_dispatch" {
  let graph = @egraph.EGraph::new()
  let eq = graph.mk_enode(@util.ExprId::new(3), [], 0)
  let th = @theory_ids.TheoryId::new(12)
  graph.attach_theory_var(eq, th, @theory_ids.TheoryVar::new(5))
  let dispatch = EGraphDispatchState::new()
  let log : Array[String] = []
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(th, "d", [])
  plugin.set_new_diseq(fn(_, _, fact) {
    log.push("diseq:\{fact.owner()}:\{fact.to_int()}")
  })
  dispatch.push()
  graph.push()
  graph.enqueue_new_diseq(eq)
  dispatch.drain_new_facts(
    graph,
    [plugin],
    @theory_core.TheoryContextView::new(scope_depth=1),
    fn(_) { @theory_core.TheoryActions::noop() },
  )
  inspect(log.join(">"), content="diseq:th#12:0")
  inspect(dispatch.diseq_fact_count(), content="1")
  graph.pop(1)
  dispatch.pop(1)
  inspect(dispatch.diseq_fact_count(), content="0")
}

///|
test "smt_context_owns_egraph_dispatch_state_and_scopes_facts" {
  let manager = @ast.AstManager::new()
  let lhs = bool_const(manager, "dispatch_lhs")
  let rhs = bool_const(manager, "dispatch_rhs")
  let context = SmtContext::new(manager)
  let th = @theory_ids.TheoryId::new(13)
  context.attach_theory_var(lhs, th, @theory_ids.TheoryVar::new(1))
  context.attach_theory_var(rhs, th, @theory_ids.TheoryVar::new(2))
  let log : Array[String] = []
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(th, "ctx", [])
  plugin.set_new_eq(fn(_, _, fact) {
    log.push("eq:\{fact.owner()}:\{fact.to_int()}")
  })
  context.register_theory(plugin)
  context.enqueue_egraph_eq(lhs, rhs)
  context.dispatch_egraph_facts()
  context.dispatch_egraph_facts()
  inspect(log.join(">"), content="eq:th#13:0")
  inspect(context.egraph_eq_fact_count(), content="1")
  context.push()
  context.enqueue_egraph_eq(rhs, lhs)
  context.dispatch_egraph_facts()
  inspect(context.egraph_eq_fact_count(), content="2")
  context.pop(1)
  inspect(context.egraph_eq_fact_count(), content="1")
}

///|
test "smt_context_check_sat_drains_queued_egraph_facts_before_theory_check" {
  let manager = @ast.AstManager::new()
  let lhs = bool_const(manager, "auto_dispatch_lhs")
  let rhs = bool_const(manager, "auto_dispatch_rhs")
  let context = SmtContext::new(manager)
  let th = @theory_ids.TheoryId::new(14)
  context.attach_theory_var(lhs, th, @theory_ids.TheoryVar::new(1))
  context.attach_theory_var(rhs, th, @theory_ids.TheoryVar::new(2))
  let log : Array[String] = []
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(th, "ctx", [])
  plugin.set_new_eq(fn(_, _, fact) { log.push("eq:\{fact.to_int()}") })
  plugin.set_theory_check(fn(_, _) {
    log.push("check")
    @theory_core.TheoryCheckDone
  })
  context.register_theory(plugin)
  context.enqueue_egraph_eq(lhs, rhs)
  ignore(context.check_sat())
  inspect(log.join(">"), content="eq:0>check")
}
