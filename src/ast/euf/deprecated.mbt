///|
pub(all) enum EufStatus {
  EufSat
  EufUnsat
} derive(Eq)

///|
pub struct EufSolver {
  priv manager : @ast.AstManager
  priv graph : @egraph.EGraph
  priv congruence : @egraph.EGraphCongruence
  priv mut scope_depth : Int
}

///|
pub fn EufSolver::new(manager : @ast.AstManager) -> EufSolver {
  {
    manager,
    graph: @egraph.EGraph::new(),
    congruence: @egraph.EGraphCongruence::new(),
    scope_depth: 0,
  }
}

///|
fn EufSolver::expect_same_sort(
  self : EufSolver,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> Unit raise @type_error.TypeError {
  if self.manager.expr_sort(lhs) != self.manager.expr_sort(rhs) {
    raise @type_error.TypeError("EUF terms have different sorts", None)
  }
}

///|
fn EufSolver::expect_euf_sort(
  self : EufSolver,
  expr : @util.ExprId,
) -> Unit raise @type_error.TypeError {
  if self.manager.expr_sort(expr) == self.manager.bool_sort() {
    raise @type_error.TypeError("expected non-Bool EUF term", None)
  }
}

///|
fn EufSolver::make_term(
  self : EufSolver,
  expr_id : @util.ExprId,
) -> @egraph.EnodeId raise @type_error.TypeError {
  let expanded = self.manager.expand_macros(expr_id).result()
  self.expect_euf_sort(expanded)
  match self.manager.get_expr(expanded).kind {
    App(decl, args) => {
      let child_nodes : Array[@egraph.EnodeId] = []
      for arg in args {
        child_nodes.push(self.make_term(arg))
      }
      let node = self.graph.mk_enode_with_key(
        expanded,
        child_nodes,
        self.scope_depth,
        decl.to_int(),
      )
      self.congruence.add_term(node)
      node
    }
    _ => raise @type_error.TypeError("expected uninterpreted term", None)
  }
}

///|
fn EufSolver::close(self : EufSolver) -> Unit {
  self.congruence.close(self.graph)
}

///|
pub fn EufSolver::assert_equal(
  self : EufSolver,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> Unit raise @type_error.TypeError {
  self.expect_same_sort(lhs, rhs)
  let lhs_node = self.make_term(lhs)
  let rhs_node = self.make_term(rhs)
  ignore(self.congruence.merge(lhs_node, rhs_node))
  self.graph.enqueue_new_eq(lhs_node, rhs_node)
  self.close()
}

///|
pub fn EufSolver::assert_disequal(
  self : EufSolver,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> Unit raise @type_error.TypeError {
  self.expect_same_sort(lhs, rhs)
  let lhs_node = self.make_term(lhs)
  let rhs_node = self.make_term(rhs)
  self.congruence.assert_disequal(lhs_node, rhs_node)
  self.graph.enqueue_new_diseq(lhs_node)
  self.close()
}

///|
pub fn EufSolver::same_class(
  self : EufSolver,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> Bool raise @type_error.TypeError {
  self.expect_same_sort(lhs, rhs)
  let lhs_node = self.make_term(lhs)
  let rhs_node = self.make_term(rhs)
  self.close()
  self.congruence.same_class(lhs_node, rhs_node)
}

///|
pub fn EufSolver::check(self : EufSolver) -> EufStatus {
  self.close()
  if self.congruence.has_conflict() {
    EufUnsat
  } else {
    EufSat
  }
}

///|
pub fn EufSolver::push_scope(self : EufSolver) -> Unit {
  self.graph.push()
  self.congruence.push()
  self.scope_depth += 1
}

///|
pub fn EufSolver::pop_scope(
  self : EufSolver,
  count : Int,
) -> Unit raise @solver_error.SolverError {
  if count < 0 {
    raise @solver_error.SolverError("cannot pop a negative number of scopes")
  } else if count > self.scope_depth {
    raise @solver_error.SolverError(
      "cannot pop \{count} scope(s); only \{self.scope_depth} scope(s) are active",
    )
  } else if count == 0 {
    ()
  } else {
    self.graph.pop(count)
    self.congruence.pop(count)
    self.scope_depth -= count
  }
}
