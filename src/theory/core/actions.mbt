///|
pub struct TheoryTermRef {
  priv owner : @ids.TheoryId
  priv value : Int
  priv scope_generation : Int
} derive(Eq)

///|
pub fn TheoryTermRef::new(
  owner : @ids.TheoryId,
  value : Int,
  scope_generation~ : Int,
) -> TheoryTermRef {
  { owner, value, scope_generation }
}

///|
pub fn TheoryTermRef::owner(self : TheoryTermRef) -> @ids.TheoryId {
  self.owner
}

///|
pub fn TheoryTermRef::to_int(self : TheoryTermRef) -> Int {
  self.value
}

///|
pub fn TheoryTermRef::scope_generation(self : TheoryTermRef) -> Int {
  self.scope_generation
}

///|
pub fn TheoryTermRef::is_valid_at(
  self : TheoryTermRef,
  scope_depth : Int,
) -> Bool {
  scope_depth >= self.scope_generation
}

///|
pub impl Show for TheoryTermRef with fn output(self, logger) {
  logger.write_string("\{self.owner}:\{self.value}")
}

///|
pub struct EqFact {
  priv owner : @ids.TheoryId
  priv value : Int
  priv scope_generation : Int
} derive(Eq)

///|
pub fn EqFact::new(
  owner : @ids.TheoryId,
  value : Int,
  scope_generation~ : Int,
) -> EqFact {
  { owner, value, scope_generation }
}

///|
pub fn EqFact::owner(self : EqFact) -> @ids.TheoryId {
  self.owner
}

///|
pub fn EqFact::to_int(self : EqFact) -> Int {
  self.value
}

///|
pub fn EqFact::scope_generation(self : EqFact) -> Int {
  self.scope_generation
}

///|
pub fn EqFact::is_valid_at(self : EqFact, scope_depth : Int) -> Bool {
  scope_depth >= self.scope_generation
}

///|
pub impl Show for EqFact with fn output(self, logger) {
  logger.write_string("\{self.owner}:\{self.value}")
}

///|
pub struct DiseqFact {
  priv owner : @ids.TheoryId
  priv value : Int
  priv scope_generation : Int
} derive(Eq)

///|
pub fn DiseqFact::new(
  owner : @ids.TheoryId,
  value : Int,
  scope_generation~ : Int,
) -> DiseqFact {
  { owner, value, scope_generation }
}

///|
pub fn DiseqFact::owner(self : DiseqFact) -> @ids.TheoryId {
  self.owner
}

///|
pub fn DiseqFact::to_int(self : DiseqFact) -> Int {
  self.value
}

///|
pub fn DiseqFact::scope_generation(self : DiseqFact) -> Int {
  self.scope_generation
}

///|
pub fn DiseqFact::is_valid_at(self : DiseqFact, scope_depth : Int) -> Bool {
  scope_depth >= self.scope_generation
}

///|
pub impl Show for DiseqFact with fn output(self, logger) {
  logger.write_string("\{self.owner}:\{self.value}")
}

///|
pub struct AntecedentId {
  priv owner : @ids.TheoryId
  priv value : Int
  priv scope_generation : Int
} derive(Eq)

///|
pub fn AntecedentId::new(
  owner : @ids.TheoryId,
  value : Int,
  scope_generation~ : Int,
) -> AntecedentId {
  { owner, value, scope_generation }
}

///|
pub fn AntecedentId::owner(self : AntecedentId) -> @ids.TheoryId {
  self.owner
}

///|
pub fn AntecedentId::to_int(self : AntecedentId) -> Int {
  self.value
}

///|
pub fn AntecedentId::is_valid_at(
  self : AntecedentId,
  scope_depth : Int,
) -> Bool {
  scope_depth >= self.scope_generation
}

///|
pub impl Show for AntecedentId with fn output(self, logger) {
  logger.write_string("\{self.owner}:antecedent#\{self.value}")
}

///|
pub struct ProofHintId {
  priv owner : @ids.TheoryId
  priv value : Int
  priv scope_generation : Int
} derive(Eq)

///|
pub fn ProofHintId::new(
  owner : @ids.TheoryId,
  value : Int,
  scope_generation~ : Int,
) -> ProofHintId {
  { owner, value, scope_generation }
}

///|
pub fn ProofHintId::owner(self : ProofHintId) -> @ids.TheoryId {
  self.owner
}

///|
pub fn ProofHintId::to_int(self : ProofHintId) -> Int {
  self.value
}

///|
pub fn ProofHintId::is_valid_at(self : ProofHintId, scope_depth : Int) -> Bool {
  scope_depth >= self.scope_generation
}

///|
pub impl Show for ProofHintId with fn output(self, logger) {
  logger.write_string("\{self.owner}:proof-hint#\{self.value}")
}

///|
pub struct TheoryContextView {
  priv scope_depth : Int
}

///|
pub fn TheoryContextView::new(scope_depth~ : Int) -> TheoryContextView {
  { scope_depth, }
}

///|
pub fn TheoryContextView::scope_depth(self : TheoryContextView) -> Int {
  self.scope_depth
}

///|
pub struct TheoryAssertedLiteral {
  priv literal : @sat.Literal
}

///|
pub fn TheoryAssertedLiteral::new(
  literal : @sat.Literal,
) -> TheoryAssertedLiteral {
  { literal, }
}

///|
pub fn TheoryAssertedLiteral::literal(
  self : TheoryAssertedLiteral,
) -> @sat.Literal {
  self.literal
}

///|
pub struct ModelValidationView {
  priv eval_text_fn : (@util.ExprId, Bool) -> String?
}

///|
pub fn ModelValidationView::new(
  eval_text~ : (@util.ExprId, Bool) -> String?,
) -> ModelValidationView {
  { eval_text_fn: eval_text }
}

///|
pub fn ModelValidationView::empty() -> ModelValidationView {
  ModelValidationView::new(eval_text=fn(_, _) { None })
}

///|
pub fn ModelValidationView::eval_text(
  self : ModelValidationView,
  expr : @util.ExprId,
  completion~ : Bool,
) -> String? {
  (self.eval_text_fn)(expr, completion)
}

///|
pub struct TheoryActions {
  priv scope_depth_fn : () -> Int
  priv internalize_bool_fn : (@util.ExprId) -> @sat.Literal?
  priv internalize_term_ref_fn : (@util.ExprId) -> TheoryTermRef?
  priv sat_value_fn : (@sat.Literal) -> Bool?
  priv current_root_fn : (TheoryTermRef) -> TheoryTermRef?
  priv add_clause_fn : (Array[@sat.Literal]) -> Unit
  priv add_lemma_fn : (Array[@sat.Literal]) -> Unit
  priv add_lemma_with_hint_fn : (Array[@sat.Literal], ProofHintId) -> Unit
  priv add_extension_assumption_fn : (@sat.Literal, @util.ExprId, String?) -> Unit
  priv enqueue_fn : (@sat.Literal, AntecedentId) -> Unit
  priv conflict_fn : (AntecedentId) -> Unit
  priv materialize_antecedent_fn : (AntecedentId) -> Array[@sat.Literal]
  priv create_proof_hint_fn : (@ids.TheoryId, String) -> ProofHintId
  priv mark_unknown_fn : (@util.ReasonUnknown) -> Unit
  priv params_fn : () -> @params.Params?
  priv collect_statistics_fn : () -> @stats.Statistics
}

///|
pub fn TheoryActions::noop() -> TheoryActions {
  TheoryActions::{
    scope_depth_fn: fn() { 0 },
    internalize_bool_fn: fn(_) { None },
    internalize_term_ref_fn: fn(_) { None },
    sat_value_fn: fn(_) { None },
    current_root_fn: fn(_) { None },
    add_clause_fn: fn(_) { () },
    add_lemma_fn: fn(_) { () },
    add_lemma_with_hint_fn: fn(_, _) { () },
    add_extension_assumption_fn: fn(_, _, _) { () },
    enqueue_fn: fn(_, _) { () },
    conflict_fn: fn(_) { () },
    materialize_antecedent_fn: fn(_) { [] },
    create_proof_hint_fn: fn(owner, _) {
      ProofHintId::new(owner, -1, scope_generation=0)
    },
    mark_unknown_fn: fn(_) { () },
    params_fn: fn() { None },
    collect_statistics_fn: fn() { @stats.Statistics::new() },
  }
}

///|
pub fn TheoryActions::new(
  scope_depth~ : () -> Int,
  enqueue~ : (@sat.Literal, AntecedentId) -> Unit,
  mark_unknown~ : (@util.ReasonUnknown) -> Unit,
) -> TheoryActions {
  TheoryActions::new_with_justification(
    scope_depth~,
    enqueue~,
    mark_unknown~,
    materialize_antecedent=fn(_) { [] },
    create_proof_hint=fn(owner, _) {
      ProofHintId::new(owner, -1, scope_generation=scope_depth())
    },
  )
}

///|
pub fn TheoryActions::new_with_justification(
  scope_depth~ : () -> Int,
  enqueue~ : (@sat.Literal, AntecedentId) -> Unit,
  mark_unknown~ : (@util.ReasonUnknown) -> Unit,
  materialize_antecedent~ : (AntecedentId) -> Array[@sat.Literal],
  create_proof_hint~ : (@ids.TheoryId, String) -> ProofHintId,
) -> TheoryActions {
  TheoryActions::new_with_context(
    scope_depth~,
    internalize_bool=fn(_) { None },
    add_clause=fn(_) { () },
    add_lemma=fn(_) { () },
    add_lemma_with_hint=fn(_, _) { () },
    add_extension_assumption=fn(_, _, _) { () },
    enqueue~,
    conflict=fn(_) { () },
    mark_unknown~,
    materialize_antecedent~,
    create_proof_hint~,
  )
}

///|
pub fn TheoryActions::new_with_context(
  scope_depth~ : () -> Int,
  internalize_bool~ : (@util.ExprId) -> @sat.Literal?,
  add_clause~ : (Array[@sat.Literal]) -> Unit,
  add_lemma~ : (Array[@sat.Literal]) -> Unit,
  add_lemma_with_hint~ : (Array[@sat.Literal], ProofHintId) -> Unit,
  add_extension_assumption~ : (@sat.Literal, @util.ExprId, String?) -> Unit,
  enqueue~ : (@sat.Literal, AntecedentId) -> Unit,
  conflict~ : (AntecedentId) -> Unit,
  mark_unknown~ : (@util.ReasonUnknown) -> Unit,
  materialize_antecedent~ : (AntecedentId) -> Array[@sat.Literal],
  create_proof_hint~ : (@ids.TheoryId, String) -> ProofHintId,
) -> TheoryActions {
  TheoryActions::{
    scope_depth_fn: scope_depth,
    internalize_bool_fn: internalize_bool,
    internalize_term_ref_fn: fn(_) { None },
    sat_value_fn: fn(_) { None },
    current_root_fn: fn(_) { None },
    add_clause_fn: add_clause,
    add_lemma_fn: add_lemma,
    add_lemma_with_hint_fn: add_lemma_with_hint,
    add_extension_assumption_fn: add_extension_assumption,
    enqueue_fn: enqueue,
    conflict_fn: conflict,
    materialize_antecedent_fn: materialize_antecedent,
    create_proof_hint_fn: create_proof_hint,
    mark_unknown_fn: mark_unknown,
    params_fn: fn() { None },
    collect_statistics_fn: fn() { @stats.Statistics::new() },
  }
}

///|
pub fn TheoryActions::scope_depth(self : TheoryActions) -> Int {
  (self.scope_depth_fn)()
}

///|
pub fn TheoryActions::internalize_bool(
  self : TheoryActions,
  expr : @util.ExprId,
) -> @sat.Literal? {
  (self.internalize_bool_fn)(expr)
}

///|
pub fn TheoryActions::internalize_term_ref(
  self : TheoryActions,
  expr : @util.ExprId,
) -> TheoryTermRef? {
  (self.internalize_term_ref_fn)(expr)
}

///|
pub fn TheoryActions::sat_value(
  self : TheoryActions,
  literal : @sat.Literal,
) -> Bool? {
  (self.sat_value_fn)(literal)
}

///|
pub fn TheoryActions::current_root(
  self : TheoryActions,
  term : TheoryTermRef,
) -> TheoryTermRef? {
  (self.current_root_fn)(term)
}

///|
pub fn TheoryActions::add_clause(
  self : TheoryActions,
  literals : Array[@sat.Literal],
) -> Unit {
  (self.add_clause_fn)(literals)
}

///|
pub fn TheoryActions::add_lemma(
  self : TheoryActions,
  literals : Array[@sat.Literal],
) -> Unit {
  (self.add_lemma_fn)(literals)
}

///|
pub fn TheoryActions::add_lemma_with_hint(
  self : TheoryActions,
  literals : Array[@sat.Literal],
  hint : ProofHintId,
) -> Unit {
  (self.add_lemma_with_hint_fn)(literals, hint)
}

///|
pub fn TheoryActions::add_extension_assumption(
  self : TheoryActions,
  literal : @sat.Literal,
  expr : @util.ExprId,
  name : String?,
) -> Unit {
  (self.add_extension_assumption_fn)(literal, expr, name)
}

///|
pub fn TheoryActions::enqueue(
  self : TheoryActions,
  literal : @sat.Literal,
  antecedent : AntecedentId,
) -> Unit {
  (self.enqueue_fn)(literal, antecedent)
}

///|
pub fn TheoryActions::conflict(
  self : TheoryActions,
  antecedent : AntecedentId,
) -> Unit {
  (self.conflict_fn)(antecedent)
}

///|
pub fn TheoryActions::materialize_antecedent(
  self : TheoryActions,
  antecedent : AntecedentId,
) -> Array[@sat.Literal] {
  (self.materialize_antecedent_fn)(antecedent)
}

///|
pub fn TheoryActions::create_proof_hint(
  self : TheoryActions,
  owner : @ids.TheoryId,
  kind : String,
) -> ProofHintId {
  (self.create_proof_hint_fn)(owner, kind)
}

///|
pub fn TheoryActions::mark_unknown(
  self : TheoryActions,
  reason : @util.ReasonUnknown,
) -> Unit {
  (self.mark_unknown_fn)(reason)
}

///|
pub fn TheoryActions::params(self : TheoryActions) -> @params.Params? {
  (self.params_fn)()
}

///|
pub fn TheoryActions::params_available(self : TheoryActions) -> Bool {
  match self.params() {
    Some(_) => true
    None => false
  }
}

///|
pub fn TheoryActions::collect_statistics(
  self : TheoryActions,
) -> @stats.Statistics {
  (self.collect_statistics_fn)()
}
