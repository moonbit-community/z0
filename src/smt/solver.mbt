///|
pub struct Solver {
  priv manager : @ast.AstManager
  priv context : SmtContext
  priv assertions : @util.ScopedVector[@util.ExprId]
  priv mut last_model : @model.Model?
}

///|
pub fn Solver::new(manager : @ast.AstManager) -> Solver {
  Solver::{
    manager,
    context: SmtContext::new(manager),
    assertions: @util.ScopedVector::new(),
    last_model: None,
  }
}

///|
pub fn Solver::setup_theories(
  self : Solver,
  registry : TheoryRegistry,
  mode : SmtSetupMode,
  params : @params.Params,
) -> Unit {
  self.context.setup_theories(registry, mode, params)
}

///|
pub fn Solver::registered_theory_count(self : Solver) -> Int {
  self.context.registered_theory_count()
}

///|
pub fn Solver::assert_expr(
  self : Solver,
  expr : @util.ExprId,
) -> Unit raise @type_error.TypeError {
  if self.manager.expr_sort(expr) != self.manager.bool_sort() {
    raise @type_error.TypeError("expected Bool assertion", None)
  } else {
    self.assertions.push_item(expr)
    self.context.assert_expr(expr)
    self.last_model = None
  }
}

///|
pub fn Solver::push(
  self : Solver,
  count : Int,
) -> Unit raise @solver_error.SolverError {
  if count < 0 {
    raise @solver_error.SolverError("cannot push a negative number of scopes")
  } else {
    for _ in 0..<count {
      self.assertions.push_scope()
      self.context.push()
    }
    self.last_model = None
  }
}

///|
pub fn Solver::pop(
  self : Solver,
  count : Int,
) -> Unit raise @solver_error.SolverError {
  self.last_model = None
  self.assertions.pop_scope(count)
  self.context.pop(count)
}

///|
pub fn Solver::check_sat(self : Solver) -> SolverResult {
  match self.context.check_sat() {
    SmtContextSat(model) => {
      self.last_model = Some(model)
      Sat
    }
    SmtContextUnsat => {
      self.last_model = None
      Unsat
    }
    SmtContextUnknown(reason) => {
      self.last_model = None
      Unknown(reason)
    }
  }
}

///|
pub fn Solver::check_sat_assuming(
  self : Solver,
  assumptions : Array[@util.ExprId],
) -> SolverAssumptionResult {
  match self.context.check_sat_assuming(assumptions) {
    SmtAssumptionSat => {
      self.last_model = self.context.last_model()
      AssumptionSat
    }
    SmtAssumptionUnsat(core, entries) => {
      self.last_model = None
      AssumptionUnsat(core, entries)
    }
    SmtAssumptionUnknown(reason) => {
      self.last_model = None
      AssumptionUnknown(reason)
    }
  }
}

///|
pub fn Solver::get_model(self : Solver) -> @model.Model? {
  self.last_model
}

///|
pub fn Solver::proof_object(self : Solver) -> @proof.ProofObject {
  self.context.proof_object()
}

///|
pub fn Solver::checked_proof_object(
  self : Solver,
) -> @util.Availability[@proof.ProofObject] {
  let proof = self.proof_object()
  match self.context.check_proof_object(proof) {
    @util.Available(_) => @util.Available(proof)
    @util.Unavailable(reason) => @util.Unavailable(reason)
  }
}

///|
pub fn Solver::context_sat_core_id(self : Solver) -> Int {
  self.context.sat_core_id()
}

///|
pub fn Solver::context_root_clause_count(self : Solver) -> Int {
  self.context.root_clause_count()
}

///|
pub fn Solver::get_scope_level(self : Solver) -> Int {
  self.assertions.scope_depth()
}

///|
pub fn Solver::get_num_assertions(self : Solver) -> Int {
  self.assertions.length()
}

///|
pub fn Solver::get_assertion(self : Solver, index : Int) -> @util.ExprId? {
  self.assertions.items().get(index)
}
