///|
pub(all) enum TheoryInternalizeResult {
  TheoryHandled(TheoryTermRef)
  TheoryNotOwned
  TheoryUnsupported(@util.ReasonUnknown)
} derive(Eq)

///|
pub(all) enum TheoryPropagateResult {
  TheoryPropagateDone
  TheoryPropagateGiveUp(@util.ReasonUnknown)
} derive(Eq)

///|
pub(all) enum TheoryCheckResult {
  TheoryCheckContinue
  TheoryCheckDone
  TheoryCheckGiveUp(@util.ReasonUnknown)
} derive(Eq)

///|
pub struct TheoryPlugin {
  priv id : @ids.TheoryId
  priv name : String
  priv families : Array[@ast.FamilyId]
  priv mut configure_fn : (@params.Params) -> Unit
  priv mut describe_params_fn : () -> @params.ParamDescrs
  priv mut updt_params_fn : (@params.Params) -> @util.Availability[Unit]
  priv mut internalize_atom_fn : (
    TheoryContextView,
    TheoryActions,
    @ast.FamilyId,
    @util.ExprId,
  ) -> TheoryInternalizeResult
  priv mut internalize_term_fn : (
    TheoryContextView,
    TheoryActions,
    @ast.FamilyId,
    @util.ExprId,
  ) -> TheoryInternalizeResult
  priv mut internalize_equality_fn : (
    TheoryContextView,
    TheoryActions,
    @util.ExprId,
    @util.ExprId,
  ) -> TheoryInternalizeResult
  priv mut asserted_fn : (
    TheoryContextView,
    TheoryActions,
    TheoryAssertedLiteral,
  ) -> Unit
  priv mut new_eq_fn : (TheoryContextView, TheoryActions, EqFact) -> Unit
  priv mut new_diseq_fn : (TheoryContextView, TheoryActions, DiseqFact) -> Unit
  priv mut relevant_fn : (TheoryContextView, TheoryTermRef) -> Unit
  priv mut push_fn : (TheoryContextView) -> Unit
  priv mut pop_fn : (TheoryContextView, Int) -> Unit
  priv mut restart_fn : (TheoryContextView) -> Unit
  priv mut init_search_fn : (TheoryContextView, TheoryActions) -> Unit
  priv mut can_propagate_fn : (TheoryContextView) -> Bool
  priv mut propagate_fn : (TheoryContextView, TheoryActions) -> TheoryPropagateResult
  priv mut theory_check_fn : (TheoryContextView, TheoryActions) -> TheoryCheckResult
  priv mut finalize_check_fn : (TheoryContextView, TheoryActions) -> Unit
  priv mut on_check_done_fn : (TheoryContextView, TheoryActions) -> Unit
  priv mut init_model_fn : (TheoryContextView, TheoryActions) -> Unit
  priv mut mk_value_fn : (TheoryContextView, TheoryActions, TheoryTermRef) -> @util.ExprId?
  priv mut model_add_dep_fn : (
    TheoryContextView,
    TheoryActions,
    TheoryTermRef,
    @util.ExprId,
  ) -> Unit
  priv mut model_add_value_fn : (
    TheoryContextView,
    TheoryActions,
    TheoryTermRef,
    @util.ExprId,
  ) -> Unit
  priv mut include_func_interp_fn : (@util.FuncDeclId) -> Bool
  priv mut has_unhandled_fn : () -> Bool
  priv mut model_incomplete_reason_fn : () -> @util.ReasonUnknown?
  priv mut finalize_model_fn : (TheoryContextView, TheoryActions) -> Unit
  priv mut validate_model_fn : (
    TheoryContextView,
    TheoryActions,
    ModelValidationView,
  ) -> @util.Availability[Unit]
  priv mut validate_unsat_core_fn : (TheoryContextView, TheoryActions) -> @util.Availability[
    Unit,
  ]
  priv mut get_antecedents_fn : (AntecedentId) -> Array[@sat.Literal]
  priv mut proof_hint_fn : (ProofHintId) -> String
  priv mut collect_statistics_fn : () -> @stats.Statistics
}

///|
fn default_internalize_unsupported(
  name : String,
  feature : String,
) -> TheoryInternalizeResult {
  TheoryUnsupported(
    @util.ReasonUnknown::unsupported_fragment("\{name}:\{feature}"),
  )
}

///|
pub fn TheoryPlugin::default_unimplemented(
  id : @ids.TheoryId,
  name : String,
  families : Array[@ast.FamilyId],
) -> TheoryPlugin {
  TheoryPlugin::{
    id,
    name,
    families: families.copy(),
    configure_fn: fn(_) { () },
    describe_params_fn: fn() { @params.ParamDescrs::new() },
    updt_params_fn: fn(_) { @util.Available(()) },
    internalize_atom_fn: fn(_, _, _, _) {
      default_internalize_unsupported(name, "internalize-atom")
    },
    internalize_term_fn: fn(_, _, _, _) {
      default_internalize_unsupported(name, "internalize-term")
    },
    internalize_equality_fn: fn(_, _, _, _) {
      default_internalize_unsupported(name, "internalize-equality")
    },
    asserted_fn: fn(_, _, _) { () },
    new_eq_fn: fn(_, _, _) { () },
    new_diseq_fn: fn(_, _, _) { () },
    relevant_fn: fn(_, _) { () },
    push_fn: fn(_) { () },
    pop_fn: fn(_, _) { () },
    restart_fn: fn(_) { () },
    init_search_fn: fn(_, _) { () },
    can_propagate_fn: fn(_) { false },
    propagate_fn: fn(_, _) { TheoryPropagateDone },
    theory_check_fn: fn(_, _) { TheoryCheckDone },
    finalize_check_fn: fn(_, _) { () },
    on_check_done_fn: fn(_, _) { () },
    init_model_fn: fn(_, _) { () },
    mk_value_fn: fn(_, _, _) { None },
    model_add_dep_fn: fn(_, _, _, _) { () },
    model_add_value_fn: fn(_, _, _, _) { () },
    include_func_interp_fn: fn(_) { false },
    has_unhandled_fn: fn() { false },
    model_incomplete_reason_fn: fn() { None },
    finalize_model_fn: fn(_, _) { () },
    validate_model_fn: fn(_, _, _) { @util.Available(()) },
    validate_unsat_core_fn: fn(_, _) { @util.Available(()) },
    get_antecedents_fn: fn(_) { [] },
    proof_hint_fn: fn(_) { "" },
    collect_statistics_fn: fn() { @stats.Statistics::new() },
  }
}

///|
pub fn TheoryPlugin::id(self : TheoryPlugin) -> @ids.TheoryId {
  self.id
}

///|
pub fn TheoryPlugin::name(self : TheoryPlugin) -> String {
  self.name
}

///|
pub fn TheoryPlugin::families(self : TheoryPlugin) -> Array[@ast.FamilyId] {
  self.families.copy()
}

///|
pub fn TheoryPlugin::owns_family(
  self : TheoryPlugin,
  family : @ast.FamilyId,
) -> Bool {
  for candidate in self.families {
    if candidate == family {
      return true
    }
  }
  false
}

///|
pub fn TheoryPlugin::configure(
  self : TheoryPlugin,
  params : @params.Params,
) -> Unit {
  ignore(self.updt_params(params))
}

///|
pub fn TheoryPlugin::set_configure(
  self : TheoryPlugin,
  callback : (@params.Params) -> Unit,
) -> Unit {
  self.configure_fn = callback
}

///|
pub fn TheoryPlugin::describe_params(
  self : TheoryPlugin,
) -> @params.ParamDescrs {
  (self.describe_params_fn)()
}

///|
pub fn TheoryPlugin::set_describe_params(
  self : TheoryPlugin,
  callback : () -> @params.ParamDescrs,
) -> Unit {
  self.describe_params_fn = callback
}

///|
pub fn TheoryPlugin::updt_params(
  self : TheoryPlugin,
  params : @params.Params,
) -> @util.Availability[Unit] {
  (self.configure_fn)(params)
  (self.updt_params_fn)(params)
}

///|
pub fn TheoryPlugin::set_updt_params(
  self : TheoryPlugin,
  callback : (@params.Params) -> @util.Availability[Unit],
) -> Unit {
  self.updt_params_fn = callback
}

///|
pub fn TheoryPlugin::internalize_atom(
  self : TheoryPlugin,
  view : TheoryContextView,
  actions : TheoryActions,
  family : @ast.FamilyId,
  expr : @util.ExprId,
) -> TheoryInternalizeResult {
  if !self.owns_family(family) {
    TheoryNotOwned
  } else {
    (self.internalize_atom_fn)(view, actions, family, expr)
  }
}

///|
pub fn TheoryPlugin::set_internalize_atom(
  self : TheoryPlugin,
  callback : (TheoryContextView, TheoryActions, @ast.FamilyId, @util.ExprId) -> TheoryInternalizeResult,
) -> Unit {
  self.internalize_atom_fn = callback
}

///|
pub fn TheoryPlugin::internalize_term(
  self : TheoryPlugin,
  view : TheoryContextView,
  actions : TheoryActions,
  family : @ast.FamilyId,
  expr : @util.ExprId,
) -> TheoryInternalizeResult {
  if !self.owns_family(family) {
    TheoryNotOwned
  } else {
    (self.internalize_term_fn)(view, actions, family, expr)
  }
}

///|
pub fn TheoryPlugin::set_internalize_term(
  self : TheoryPlugin,
  callback : (TheoryContextView, TheoryActions, @ast.FamilyId, @util.ExprId) -> TheoryInternalizeResult,
) -> Unit {
  self.internalize_term_fn = callback
}

///|
pub fn TheoryPlugin::internalize_equality(
  self : TheoryPlugin,
  view : TheoryContextView,
  actions : TheoryActions,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> TheoryInternalizeResult {
  (self.internalize_equality_fn)(view, actions, lhs, rhs)
}

///|
pub fn TheoryPlugin::set_internalize_equality(
  self : TheoryPlugin,
  callback : (TheoryContextView, TheoryActions, @util.ExprId, @util.ExprId) -> TheoryInternalizeResult,
) -> Unit {
  self.internalize_equality_fn = callback
}

///|
pub fn TheoryPlugin::asserted(
  self : TheoryPlugin,
  view : TheoryContextView,
  actions : TheoryActions,
  asserted : TheoryAssertedLiteral,
) -> Unit {
  (self.asserted_fn)(view, actions, asserted)
}

///|
pub fn TheoryPlugin::set_asserted(
  self : TheoryPlugin,
  callback : (TheoryContextView, TheoryActions, TheoryAssertedLiteral) -> Unit,
) -> Unit {
  self.asserted_fn = callback
}

///|
pub fn TheoryPlugin::new_eq(
  self : TheoryPlugin,
  view : TheoryContextView,
  actions : TheoryActions,
  fact : EqFact,
) -> Unit {
  (self.new_eq_fn)(view, actions, fact)
}

///|
pub fn TheoryPlugin::set_new_eq(
  self : TheoryPlugin,
  callback : (TheoryContextView, TheoryActions, EqFact) -> Unit,
) -> Unit {
  self.new_eq_fn = callback
}

///|
pub fn TheoryPlugin::new_diseq(
  self : TheoryPlugin,
  view : TheoryContextView,
  actions : TheoryActions,
  fact : DiseqFact,
) -> Unit {
  (self.new_diseq_fn)(view, actions, fact)
}

///|
pub fn TheoryPlugin::set_new_diseq(
  self : TheoryPlugin,
  callback : (TheoryContextView, TheoryActions, DiseqFact) -> Unit,
) -> Unit {
  self.new_diseq_fn = callback
}

///|
pub fn TheoryPlugin::relevant(
  self : TheoryPlugin,
  view : TheoryContextView,
  term : TheoryTermRef,
) -> Unit {
  (self.relevant_fn)(view, term)
}

///|
pub fn TheoryPlugin::set_relevant(
  self : TheoryPlugin,
  callback : (TheoryContextView, TheoryTermRef) -> Unit,
) -> Unit {
  self.relevant_fn = callback
}

///|
pub fn TheoryPlugin::push(
  self : TheoryPlugin,
  view : TheoryContextView,
) -> Unit {
  (self.push_fn)(view)
}

///|
pub fn TheoryPlugin::set_push(
  self : TheoryPlugin,
  callback : (TheoryContextView) -> Unit,
) -> Unit {
  self.push_fn = callback
}

///|
pub fn TheoryPlugin::pop(
  self : TheoryPlugin,
  view : TheoryContextView,
  count : Int,
) -> Unit {
  (self.pop_fn)(view, count)
}

///|
pub fn TheoryPlugin::set_pop(
  self : TheoryPlugin,
  callback : (TheoryContextView, Int) -> Unit,
) -> Unit {
  self.pop_fn = callback
}

///|
pub fn TheoryPlugin::restart(
  self : TheoryPlugin,
  view : TheoryContextView,
) -> Unit {
  (self.restart_fn)(view)
}

///|
pub fn TheoryPlugin::set_restart(
  self : TheoryPlugin,
  callback : (TheoryContextView) -> Unit,
) -> Unit {
  self.restart_fn = callback
}

///|
pub fn TheoryPlugin::init_search(
  self : TheoryPlugin,
  view : TheoryContextView,
  actions : TheoryActions,
) -> Unit {
  (self.init_search_fn)(view, actions)
}

///|
pub fn TheoryPlugin::set_init_search(
  self : TheoryPlugin,
  callback : (TheoryContextView, TheoryActions) -> Unit,
) -> Unit {
  self.init_search_fn = callback
}

///|
pub fn TheoryPlugin::can_propagate(
  self : TheoryPlugin,
  view : TheoryContextView,
) -> Bool {
  (self.can_propagate_fn)(view)
}

///|
pub fn TheoryPlugin::set_can_propagate(
  self : TheoryPlugin,
  callback : (TheoryContextView) -> Bool,
) -> Unit {
  self.can_propagate_fn = callback
}

///|
pub fn TheoryPlugin::propagate(
  self : TheoryPlugin,
  view : TheoryContextView,
  actions : TheoryActions,
) -> TheoryPropagateResult {
  (self.propagate_fn)(view, actions)
}

///|
pub fn TheoryPlugin::set_propagate(
  self : TheoryPlugin,
  callback : (TheoryContextView, TheoryActions) -> TheoryPropagateResult,
) -> Unit {
  self.propagate_fn = callback
}

///|
pub fn TheoryPlugin::theory_check(
  self : TheoryPlugin,
  view : TheoryContextView,
  actions : TheoryActions,
) -> TheoryCheckResult {
  (self.theory_check_fn)(view, actions)
}

///|
pub fn TheoryPlugin::set_theory_check(
  self : TheoryPlugin,
  callback : (TheoryContextView, TheoryActions) -> TheoryCheckResult,
) -> Unit {
  self.theory_check_fn = callback
}

///|
pub fn TheoryPlugin::finalize_check(
  self : TheoryPlugin,
  view : TheoryContextView,
  actions : TheoryActions,
) -> Unit {
  (self.finalize_check_fn)(view, actions)
}

///|
pub fn TheoryPlugin::set_finalize_check(
  self : TheoryPlugin,
  callback : (TheoryContextView, TheoryActions) -> Unit,
) -> Unit {
  self.finalize_check_fn = callback
}

///|
pub fn TheoryPlugin::on_check_done(
  self : TheoryPlugin,
  view : TheoryContextView,
  actions : TheoryActions,
) -> Unit {
  (self.on_check_done_fn)(view, actions)
}

///|
pub fn TheoryPlugin::set_on_check_done(
  self : TheoryPlugin,
  callback : (TheoryContextView, TheoryActions) -> Unit,
) -> Unit {
  self.on_check_done_fn = callback
}

///|
pub fn TheoryPlugin::init_model(
  self : TheoryPlugin,
  view : TheoryContextView,
  actions : TheoryActions,
) -> Unit {
  (self.init_model_fn)(view, actions)
}

///|
pub fn TheoryPlugin::set_init_model(
  self : TheoryPlugin,
  callback : (TheoryContextView, TheoryActions) -> Unit,
) -> Unit {
  self.init_model_fn = callback
}

///|
pub fn TheoryPlugin::mk_value(
  self : TheoryPlugin,
  view : TheoryContextView,
  actions : TheoryActions,
  term : TheoryTermRef,
) -> @util.ExprId? {
  (self.mk_value_fn)(view, actions, term)
}

///|
pub fn TheoryPlugin::set_mk_value(
  self : TheoryPlugin,
  callback : (TheoryContextView, TheoryActions, TheoryTermRef) -> @util.ExprId?,
) -> Unit {
  self.mk_value_fn = callback
}

///|
pub fn TheoryPlugin::model_add_dep(
  self : TheoryPlugin,
  view : TheoryContextView,
  actions : TheoryActions,
  term : TheoryTermRef,
  dep : @util.ExprId,
) -> Unit {
  (self.model_add_dep_fn)(view, actions, term, dep)
}

///|
pub fn TheoryPlugin::set_model_add_dep(
  self : TheoryPlugin,
  callback : (TheoryContextView, TheoryActions, TheoryTermRef, @util.ExprId) -> Unit,
) -> Unit {
  self.model_add_dep_fn = callback
}

///|
pub fn TheoryPlugin::model_add_value(
  self : TheoryPlugin,
  view : TheoryContextView,
  actions : TheoryActions,
  term : TheoryTermRef,
  value : @util.ExprId,
) -> Unit {
  (self.model_add_value_fn)(view, actions, term, value)
}

///|
pub fn TheoryPlugin::set_model_add_value(
  self : TheoryPlugin,
  callback : (TheoryContextView, TheoryActions, TheoryTermRef, @util.ExprId) -> Unit,
) -> Unit {
  self.model_add_value_fn = callback
}

///|
pub fn TheoryPlugin::include_func_interp(
  self : TheoryPlugin,
  decl : @util.FuncDeclId,
) -> Bool {
  (self.include_func_interp_fn)(decl)
}

///|
pub fn TheoryPlugin::set_include_func_interp(
  self : TheoryPlugin,
  callback : (@util.FuncDeclId) -> Bool,
) -> Unit {
  self.include_func_interp_fn = callback
}

///|
pub fn TheoryPlugin::has_unhandled(self : TheoryPlugin) -> Bool {
  (self.has_unhandled_fn)()
}

///|
pub fn TheoryPlugin::set_has_unhandled(
  self : TheoryPlugin,
  callback : () -> Bool,
) -> Unit {
  self.has_unhandled_fn = callback
}

///|
pub fn TheoryPlugin::model_incomplete_reason(
  self : TheoryPlugin,
) -> @util.ReasonUnknown? {
  (self.model_incomplete_reason_fn)()
}

///|
pub fn TheoryPlugin::set_model_incomplete_reason(
  self : TheoryPlugin,
  callback : () -> @util.ReasonUnknown?,
) -> Unit {
  self.model_incomplete_reason_fn = callback
}

///|
pub fn TheoryPlugin::finalize_model(
  self : TheoryPlugin,
  view : TheoryContextView,
  actions : TheoryActions,
) -> Unit {
  (self.finalize_model_fn)(view, actions)
}

///|
pub fn TheoryPlugin::set_finalize_model(
  self : TheoryPlugin,
  callback : (TheoryContextView, TheoryActions) -> Unit,
) -> Unit {
  self.finalize_model_fn = callback
}

///|
pub fn TheoryPlugin::validate_model(
  self : TheoryPlugin,
  view : TheoryContextView,
  actions : TheoryActions,
  model : ModelValidationView,
) -> @util.Availability[Unit] {
  (self.validate_model_fn)(view, actions, model)
}

///|
pub fn TheoryPlugin::set_validate_model(
  self : TheoryPlugin,
  callback : (TheoryContextView, TheoryActions, ModelValidationView) -> @util.Availability[
    Unit,
  ],
) -> Unit {
  self.validate_model_fn = callback
}

///|
pub fn TheoryPlugin::validate_unsat_core(
  self : TheoryPlugin,
  view : TheoryContextView,
  actions : TheoryActions,
) -> @util.Availability[Unit] {
  (self.validate_unsat_core_fn)(view, actions)
}

///|
pub fn TheoryPlugin::set_validate_unsat_core(
  self : TheoryPlugin,
  callback : (TheoryContextView, TheoryActions) -> @util.Availability[Unit],
) -> Unit {
  self.validate_unsat_core_fn = callback
}

///|
pub fn TheoryPlugin::get_antecedents(
  self : TheoryPlugin,
  antecedent : AntecedentId,
) -> Array[@sat.Literal] {
  (self.get_antecedents_fn)(antecedent)
}

///|
pub fn TheoryPlugin::set_get_antecedents(
  self : TheoryPlugin,
  callback : (AntecedentId) -> Array[@sat.Literal],
) -> Unit {
  self.get_antecedents_fn = callback
}

///|
pub fn TheoryPlugin::proof_hint(
  self : TheoryPlugin,
  hint : ProofHintId,
) -> String {
  (self.proof_hint_fn)(hint)
}

///|
pub fn TheoryPlugin::set_proof_hint(
  self : TheoryPlugin,
  callback : (ProofHintId) -> String,
) -> Unit {
  self.proof_hint_fn = callback
}

///|
pub fn TheoryPlugin::collect_statistics(
  self : TheoryPlugin,
) -> @stats.Statistics {
  (self.collect_statistics_fn)()
}

///|
pub fn TheoryPlugin::set_collect_statistics(
  self : TheoryPlugin,
  callback : () -> @stats.Statistics,
) -> Unit {
  self.collect_statistics_fn = callback
}
