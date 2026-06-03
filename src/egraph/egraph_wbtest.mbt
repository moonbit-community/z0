///|
fn eg_expr(value : Int) -> @util.ExprId {
  @util.ExprId::new(value)
}

///|
fn eg_parents_text(graph : EGraph, id : EnodeId) -> String {
  let parts : Array[String] = []
  for parent in graph.parents(id) {
    parts.push("\{parent}")
  }
  parts.join(",")
}

///|
test "egraph_enode_lookup_reuses_id_and_tracks_parents" {
  let graph = EGraph::new()
  let x = graph.mk_enode(eg_expr(1), [], 0)
  let fx = graph.mk_enode(eg_expr(2), [x], 0)
  inspect(graph.find(eg_expr(1)).unwrap(), content="enode#0")
  inspect(graph.find(eg_expr(2)).unwrap(), content="enode#1")
  inspect(graph.mk_enode(eg_expr(1), [], 0), content="enode#0")
  inspect(eg_parents_text(graph, x), content="\{fx}")
  inspect(graph.generation(fx), content="0")
}

///|
test "egraph_scoped_pop_removes_enode_lookup_and_parent_links" {
  let graph = EGraph::new()
  let x = graph.mk_enode(eg_expr(1), [], 0)
  graph.push()
  let fx = graph.mk_enode(eg_expr(2), [x], 1)
  inspect(graph.find(eg_expr(2)).unwrap(), content="\{fx}")
  inspect(eg_parents_text(graph, x), content="\{fx}")
  graph.pop(1)
  inspect(graph.find(eg_expr(2)) is None, content="true")
  inspect(eg_parents_text(graph, x), content="")
  inspect(graph.find(eg_expr(1)).unwrap(), content="\{x}")
}

///|
test "egraph_scoped_attachment_undo" {
  let graph = EGraph::new()
  let x = graph.mk_enode(eg_expr(1), [], 0)
  graph.attach_theory_var(x, @ids.TheoryId::new(3), @ids.TheoryVar::new(9))
  inspect(graph.theory_var_text(x, @ids.TheoryId::new(3)), content="v#9")
  graph.push()
  graph.attach_theory_var(x, @ids.TheoryId::new(3), @ids.TheoryVar::new(10))
  inspect(graph.theory_var_text(x, @ids.TheoryId::new(3)), content="v#10")
  graph.pop(1)
  inspect(graph.theory_var_text(x, @ids.TheoryId::new(3)), content="v#9")
}

///|
test "egraph_scoped_justification_validity" {
  let graph = EGraph::new()
  let root = graph.add_axiom_justification(@ids.TheoryId::new(1))
  graph.push()
  let scoped = graph.add_equality_justification(
    EnodeId::new(0),
    EnodeId::new(1),
  )
  inspect(graph.justification_valid(root), content="true")
  inspect(graph.justification_text(scoped), content="eq(enode#0,enode#1)")
  graph.pop(1)
  inspect(graph.justification_valid(root), content="true")
  inspect(graph.justification_valid(scoped), content="false")
}

///|
test "egraph_queues_are_empty_storage_only_seed" {
  let graph = EGraph::new()
  inspect(graph.new_eq_count(), content="0")
  inspect(graph.new_diseq_count(), content="0")
}

///|
test "egraph_new_fact_queues_are_scoped_and_inspectable" {
  let graph = EGraph::new()
  let lhs = graph.mk_enode(@util.ExprId::new(10), [], 0)
  let rhs = graph.mk_enode(@util.ExprId::new(11), [], 0)
  graph.enqueue_new_eq(lhs, rhs)
  graph.enqueue_new_diseq(lhs)
  inspect(graph.new_eq_count(), content="1")
  inspect(graph.new_diseq_count(), content="1")
  inspect(graph.new_eq_text(0), content="enode#0->enode#1")
  inspect(graph.new_diseq_text(0), content="enode#0")
  graph.push()
  graph.enqueue_new_eq(rhs, lhs)
  inspect(graph.new_eq_count(), content="2")
  graph.pop(1)
  inspect(graph.new_eq_count(), content="1")
}

///|
test "egraph_congruence_closes_over_matching_operator_keys" {
  let graph = EGraph::new()
  let a = graph.mk_enode_with_key(@util.ExprId::new(20), [], 0, 1)
  let b = graph.mk_enode_with_key(@util.ExprId::new(21), [], 0, 2)
  let f_a = graph.mk_enode_with_key(@util.ExprId::new(22), [a], 0, 30)
  let f_b = graph.mk_enode_with_key(@util.ExprId::new(23), [b], 0, 30)
  let cc = EGraphCongruence::new()
  cc.add_term(a)
  cc.add_term(b)
  cc.add_term(f_a)
  cc.add_term(f_b)
  ignore(cc.merge(a, b))
  cc.close(graph)
  inspect(cc.same_class(f_a, f_b), content="true")
}

///|
test "egraph_congruence_scopes_merges_and_disequalities" {
  let graph = EGraph::new()
  let a = graph.mk_enode_with_key(@util.ExprId::new(30), [], 0, 1)
  let b = graph.mk_enode_with_key(@util.ExprId::new(31), [], 0, 2)
  let cc = EGraphCongruence::new()
  cc.add_term(a)
  cc.add_term(b)
  cc.push()
  ignore(cc.merge(a, b))
  cc.assert_disequal(a, b)
  inspect(cc.has_conflict(), content="true")
  cc.pop(1)
  inspect(cc.same_class(a, b), content="false")
  inspect(cc.has_conflict(), content="false")
}
