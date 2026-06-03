///|
pub(all) enum SmtContextResult {
  SmtContextSat(@model.Model)
  SmtContextUnsat
  SmtContextUnknown(String)
}

///|
pub(all) enum SmtContextAssumptionResult {
  SmtAssumptionSat
  SmtAssumptionUnsat(Array[@util.ExprId], Array[SmtUnsatCoreEntry])
  SmtAssumptionUnknown(String)
}

///|
priv struct TheoryUnsupportedTerm {
  expr : @util.ExprId
  reason : @util.ReasonUnknown
}

///|
priv struct SmtTheoryPropagation {
  literal : @pure_sat.Literal
  justification : @pure_sat.ExtJustificationId
}

///|
priv struct SmtExtensionAssumption {
  literal : @pure_sat.Literal
  entry : SmtUnsatCoreEntry
}

///|
priv struct SmtAssumptionLiterals {
  exprs : Array[@util.ExprId]
  literals : Array[@pure_sat.Literal]
  euf_assumptions : Array[@util.ExprId]
  euf_owners : Array[@util.ExprId]
}

///|
pub struct SmtContext {
  priv manager : @ast.AstManager
  priv sat_core : @pure_sat.SatSolverCore
  priv egraph : @egraph.EGraph
  priv internalizer : SmtInternalizer
  priv assertions : @util.ScopedVector[@util.ExprId]
  priv unsupported_terms : @util.ScopedVector[TheoryUnsupportedTerm]
  priv egraph_dispatch : EGraphDispatchState
  priv justifications : SmtJustificationStore
  priv extension_assumptions : @util.ScopedVector[SmtExtensionAssumption]
  priv extension_justifications : Array[@theory_core.AntecedentId]
  priv extension_propagations : Array[SmtTheoryPropagation]
  priv extension_conflicts : Array[@pure_sat.ExtJustificationId]
  priv theories : Array[@theory_core.TheoryPlugin]
  priv mut qhead : Int
  priv mut last_model : @model.Model?
  priv mut cache_stale : Bool
  priv mut last_result : @util.ResultKind
  priv mut last_proof_assumption_scope : String?
  priv mut extension_unknown : @util.ReasonUnknown?
}

///|
pub fn SmtContext::new(manager : @ast.AstManager) -> SmtContext {
  let sat_core = @pure_sat.SatSolverCore::new()
  let egraph = @egraph.EGraph::new()
  let context = {
    manager,
    sat_core,
    egraph,
    internalizer: SmtInternalizer::new(manager, sat_core, egraph),
    assertions: @util.ScopedVector::new(),
    unsupported_terms: @util.ScopedVector::new(),
    egraph_dispatch: EGraphDispatchState::new(),
    justifications: SmtJustificationStore::new(),
    extension_assumptions: @util.ScopedVector::new(),
    extension_justifications: [],
    extension_propagations: [],
    extension_conflicts: [],
    theories: [],
    qhead: 0,
    last_model: None,
    cache_stale: false,
    last_result: @util.ResultKind::NoResult,
    last_proof_assumption_scope: None,
    extension_unknown: None,
  }
  sat_core.set_extension(context.sat_extension())
  context
}

///|
fn SmtContext::mark_caches_stale(self : SmtContext) -> Unit {
  self.last_result = @util.ResultKind::NoResult
  self.last_proof_assumption_scope = None
  match self.last_model {
    Some(_) => self.cache_stale = true
    None => ()
  }
}

///|
fn smt_mixed_conjunction_parts(
  manager : @ast.AstManager,
  expr : @util.ExprId,
) -> (Array[@util.ExprId], Array[@util.ExprId])? {
  let bool_parts : Array[@util.ExprId] = []
  let euf_parts : Array[@util.ExprId] = []
  if !smt_collect_mixed_conjunction_parts(
      manager, expr, true, bool_parts, euf_parts,
    ) {
    return None
  }
  if !bool_parts.is_empty() && !euf_parts.is_empty() {
    Some((bool_parts, euf_parts))
  } else {
    None
  }
}

///|
fn smt_collect_mixed_conjunction_parts(
  manager : @ast.AstManager,
  expr : @util.ExprId,
  polarity : Bool,
  bool_parts : Array[@util.ExprId],
  euf_parts : Array[@util.ExprId],
) -> Bool {
  let expanded = manager.expand_macros(expr) catch { _ => return false }
  match manager.get_expr(expanded.result()).kind {
    Not(inner) =>
      smt_collect_mixed_conjunction_parts(
        manager,
        inner,
        !polarity,
        bool_parts,
        euf_parts,
      )
    And(args) =>
      if polarity {
        for arg in args {
          if !smt_collect_mixed_conjunction_parts(
              manager, arg, true, bool_parts, euf_parts,
            ) {
            return false
          }
        }
        true
      } else {
        smt_collect_mixed_conjunction_leaf(
          manager, expr, polarity, bool_parts, euf_parts,
        )
      }
    Or(args) =>
      if !polarity {
        for arg in args {
          if !smt_collect_mixed_conjunction_parts(
              manager, arg, false, bool_parts, euf_parts,
            ) {
            return false
          }
        }
        true
      } else {
        smt_collect_mixed_conjunction_leaf(
          manager, expr, polarity, bool_parts, euf_parts,
        )
      }
    Implies(lhs, rhs) =>
      if !polarity {
        smt_collect_mixed_conjunction_parts(
          manager, lhs, true, bool_parts, euf_parts,
        ) &&
        smt_collect_mixed_conjunction_parts(
          manager, rhs, false, bool_parts, euf_parts,
        )
      } else {
        smt_collect_mixed_conjunction_leaf(
          manager, expr, polarity, bool_parts, euf_parts,
        )
      }
    _ =>
      smt_collect_mixed_conjunction_leaf(
        manager, expr, polarity, bool_parts, euf_parts,
      )
  }
}

///|
fn smt_polarized_root(
  manager : @ast.AstManager,
  expr : @util.ExprId,
  polarity : Bool,
) -> @util.ExprId? {
  if polarity {
    Some(expr)
  } else {
    Some(manager.mk_not(expr)) catch {
      _ => None
    }
  }
}

///|
fn smt_collect_mixed_conjunction_leaf(
  manager : @ast.AstManager,
  expr : @util.ExprId,
  polarity : Bool,
  bool_parts : Array[@util.ExprId],
  euf_parts : Array[@util.ExprId],
) -> Bool {
  match smt_polarized_root(manager, expr, polarity) {
    None => false
    Some(root) =>
      match smt_euf_assertion_route(manager, expr, polarity) {
        EGraphAssertBool => {
          bool_parts.push(root)
          true
        }
        EGraphAssertEuf => {
          euf_parts.push(root)
          true
        }
        EGraphAssertUnsupported(_) => false
      }
  }
}

///|
fn smt_mixed_conjunction_roots(
  manager : @ast.AstManager,
  expr : @util.ExprId,
) -> Array[@util.ExprId]? {
  match smt_mixed_conjunction_parts(manager, expr) {
    Some((bool_parts, euf_parts)) => {
      let roots : Array[@util.ExprId] = []
      for part in bool_parts {
        roots.push(part)
      }
      for part in euf_parts {
        roots.push(part)
      }
      Some(roots)
    }
    None => None
  }
}

///|
pub fn SmtContext::assert_expr(self : SmtContext, expr : @util.ExprId) -> Unit {
  match smt_mixed_conjunction_roots(self.manager, expr) {
    Some(roots) =>
      for root in roots {
        self.assertions.push_item(root)
      }
    None => self.assertions.push_item(expr)
  }
  self.mark_caches_stale()
}

///|
pub fn SmtContext::register_theory(
  self : SmtContext,
  plugin : @theory_core.TheoryPlugin,
) -> Unit {
  for depth in 1..<=self.assertions.scope_depth() {
    plugin.push(@theory_core.TheoryContextView::new(scope_depth=depth))
  }
  self.theories.push(plugin)
  self.mark_caches_stale()
}

///|
pub fn SmtContext::setup_theories(
  self : SmtContext,
  registry : TheoryRegistry,
  mode : SmtSetupMode,
  params : @params.Params,
) -> Unit {
  for plugin in registry.instantiate(mode) {
    plugin.configure(params)
    self.register_theory(plugin)
  }
}

///|
pub fn SmtContext::registered_theory_count(self : SmtContext) -> Int {
  self.theories.length()
}

///|
pub fn SmtContext::record_unsupported_term(
  self : SmtContext,
  expr : @util.ExprId,
  reason : @util.ReasonUnknown,
) -> Unit {
  self.unsupported_terms.push_item(TheoryUnsupportedTerm::{ expr, reason })
  self.mark_caches_stale()
}

///|
pub fn SmtContext::internalize_theory_term(
  self : SmtContext,
  family : @ast.FamilyId,
  expr : @util.ExprId,
) -> @theory_core.TheoryInternalizeResult {
  let view = self.theory_view()
  for theory in self.theories {
    let actions = self.theory_actions_for(theory)
    match theory.internalize_term(view, actions, family, expr) {
      @theory_core.TheoryHandled(term) =>
        return @theory_core.TheoryHandled(term)
      @theory_core.TheoryUnsupported(reason) => {
        self.record_unsupported_term(expr, reason)
        return @theory_core.TheoryUnsupported(reason)
      }
      @theory_core.TheoryNotOwned => ()
    }
  }
  let reason = @util.ReasonUnknown::unsupported_fragment(
    "unowned-theory-term:\{family}",
  )
  self.record_unsupported_term(expr, reason)
  @theory_core.TheoryNotOwned
}

///|
pub fn SmtContext::unsupported_term_count(self : SmtContext) -> Int {
  self.unsupported_terms.length()
}

///|
fn SmtContext::first_unsupported_reason(
  self : SmtContext,
) -> @util.ReasonUnknown? {
  let items = self.unsupported_terms.items()
  if items.is_empty() {
    None
  } else {
    ignore(items[0].expr)
    Some(items[0].reason)
  }
}

///|
fn SmtContext::theory_view(self : SmtContext) -> @theory_core.TheoryContextView {
  @theory_core.TheoryContextView::new(scope_depth=self.assertions.scope_depth())
}

///|
fn SmtContext::try_internalize_bool(
  self : SmtContext,
  expr : @util.ExprId,
) -> @pure_sat.Literal? {
  let literal = self.internalizer.internalize_bool(expr) catch {
    _ => return None
  }
  Some(literal)
}

///|
fn SmtContext::record_extension_justification(
  self : SmtContext,
  antecedent : @theory_core.AntecedentId,
) -> @pure_sat.ExtJustificationId {
  let justification = @pure_sat.ExtJustificationId::new(
    self.extension_justifications.length(),
  )
  self.extension_justifications.push(antecedent)
  justification
}

///|
fn SmtContext::enqueue_theory_propagation(
  self : SmtContext,
  literal : @pure_sat.Literal,
  antecedent : @theory_core.AntecedentId,
) -> Unit {
  let justification = self.record_extension_justification(antecedent)
  self.extension_propagations.push(SmtTheoryPropagation::{
    literal,
    justification,
  })
}

///|
fn SmtContext::enqueue_theory_conflict(
  self : SmtContext,
  antecedent : @theory_core.AntecedentId,
) -> Unit {
  self.extension_conflicts.push(self.record_extension_justification(antecedent))
}

///|
fn SmtContext::clear_extension_actions(self : SmtContext) -> Unit {
  self.extension_justifications.truncate(0)
  self.extension_propagations.truncate(0)
  self.extension_conflicts.truncate(0)
  self.extension_unknown = None
}

///|
fn SmtContext::extension_assumption_contains(
  self : SmtContext,
  literal : @pure_sat.Literal,
) -> Bool {
  for assumption in self.extension_assumptions.items() {
    if assumption.literal == literal {
      return true
    }
  }
  false
}

///|
fn SmtContext::extension_assumption_var_contains(
  self : SmtContext,
  bool_var : @pure_sat.BoolVar,
) -> Bool {
  for assumption in self.extension_assumptions.items() {
    if assumption.literal.bool_var() == bool_var {
      return true
    }
  }
  false
}

///|
fn SmtContext::add_extension_assumption(
  self : SmtContext,
  literal : @pure_sat.Literal,
  expr : @util.ExprId,
  name : String?,
) -> Unit {
  if !self.extension_assumption_contains(literal) {
    self.extension_assumptions.push_item(SmtExtensionAssumption::{
      literal,
      entry: SmtUnsatCoreEntry::new(expr, name),
    })
  }
}

///|
fn SmtContext::extension_tracking_assumptions(
  self : SmtContext,
) -> Array[@pure_sat.Literal] {
  [
    for assumption in self.extension_assumptions.items() => assumption.literal
  ]
}

///|
fn smt_core_entry_contains(
  values : Array[SmtUnsatCoreEntry],
  value : SmtUnsatCoreEntry,
) -> Bool {
  for existing in values {
    if existing == value {
      return true
    }
  }
  false
}

///|
fn SmtContext::extension_core_entries(
  self : SmtContext,
  core : @pure_sat.AssumptionCore,
) -> Array[SmtUnsatCoreEntry] {
  let result : Array[SmtUnsatCoreEntry] = []
  let assumptions = self.extension_assumptions.items()
  for literal in core.literals() {
    for assumption in assumptions {
      if assumption.literal == literal {
        if !smt_core_entry_contains(result, assumption.entry) {
          result.push(assumption.entry)
        }
        break
      }
    }
  }
  result
}

///|
fn SmtContext::add_theory_clause(
  self : SmtContext,
  literals : Array[@pure_sat.Literal],
  owner~ : String,
  redundant~ : Bool,
  hint~ : String?,
) -> Unit {
  ignore(
    self.sat_core.add_theory_clause(
      @pure_sat.Clause::new(literals),
      owner~,
      redundant~,
      hint~,
    ),
  )
  self.mark_caches_stale()
}

///|
fn SmtContext::materialize_euf_conflict_proof(self : SmtContext) -> Unit {
  self.materialize_euf_conflict_proof_with_hint(
    self.euf_congruence_hint_for_assertions(),
  )
}

///|
fn SmtContext::materialize_euf_conflict_proof_with_hint(
  self : SmtContext,
  hint : String,
) -> Unit {
  if self.sat_core.has_unsat_proof_clause() {
    return
  }
  for theory in self.theories {
    if theory.name() == "euf" {
      self.add_theory_clause(
        [],
        owner=theory.name(),
        redundant=true,
        hint=Some(hint),
      )
      return
    }
  }
}

///|
fn euf_negated_equality_inner(
  manager : @ast.AstManager,
  expr : @util.ExprId,
) -> @util.ExprId? {
  let expanded = manager.expand_macros(expr) catch { _ => return None }
  match manager.get_expr(expanded.result()).kind {
    Not(inner) =>
      match manager.get_expr(inner).kind {
        Eq(_, _) => Some(inner)
        _ => None
      }
    _ => None
  }
}

///|
fn euf_same_unordered_pair(
  lhs : @util.ExprId,
  rhs : @util.ExprId,
  expected_lhs : @util.ExprId,
  expected_rhs : @util.ExprId,
) -> Bool {
  (lhs == expected_lhs && rhs == expected_rhs) ||
  (lhs == expected_rhs && rhs == expected_lhs)
}

///|
fn SmtContext::euf_asserted_equality_text(
  self : SmtContext,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> String {
  for assertion in self.assertions.items() {
    match self.manager.get_expr(assertion).kind {
      Eq(asserted_lhs, asserted_rhs) =>
        if euf_same_unordered_pair(asserted_lhs, asserted_rhs, lhs, rhs) {
          return self.manager.pretty(assertion)
        }
      _ => ()
    }
  }
  "(= \{self.manager.pretty(lhs)} \{self.manager.pretty(rhs)})"
}

///|
priv struct EufEqualityEdge {
  lhs : @util.ExprId
  rhs : @util.ExprId
  assertion : @util.ExprId
}

///|
fn EufEqualityEdge::other(
  self : EufEqualityEdge,
  current : @util.ExprId,
) -> @util.ExprId? {
  if self.lhs == current {
    Some(self.rhs)
  } else if self.rhs == current {
    Some(self.lhs)
  } else {
    None
  }
}

///|
fn SmtContext::euf_asserted_equality_edges(
  self : SmtContext,
) -> Array[EufEqualityEdge] {
  let edges : Array[EufEqualityEdge] = []
  for assertion in self.assertions.items() {
    match self.manager.get_expr(assertion).kind {
      Eq(lhs, rhs) => edges.push(EufEqualityEdge::{ lhs, rhs, assertion })
      _ => ()
    }
  }
  edges
}

///|
fn SmtContext::euf_collect_equality_path(
  self : SmtContext,
  current : @util.ExprId,
  target : @util.ExprId,
  edges : Array[EufEqualityEdge],
  visited : Array[@util.ExprId],
  path : Array[@util.ExprId],
) -> Bool {
  if current == target {
    return true
  }
  visited.push(current)
  for edge in edges {
    match edge.other(current) {
      Some(next) =>
        if !expr_array_contains(visited, next) {
          path.push(edge.assertion)
          if self.euf_collect_equality_path(next, target, edges, visited, path) {
            return true
          }
          path.truncate(path.length() - 1)
        }
      None => ()
    }
  }
  false
}

///|
fn SmtContext::euf_asserted_equality_chain_texts(
  self : SmtContext,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> Array[String]? {
  let path : Array[@util.ExprId] = []
  if self.euf_collect_equality_path(
      lhs,
      rhs,
      self.euf_asserted_equality_edges(),
      [],
      path,
    ) {
    Some([ for assertion in path => self.manager.pretty(assertion) ])
  } else {
    None
  }
}

///|
fn SmtContext::euf_congruence_premise_texts(
  self : SmtContext,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> Array[String]? {
  match (self.manager.get_expr(lhs).kind, self.manager.get_expr(rhs).kind) {
    (App(lhs_decl, lhs_args), App(rhs_decl, rhs_args)) =>
      if lhs_decl == rhs_decl && lhs_args.length() == rhs_args.length() {
        let parts : Array[String] = []
        for i in 0..<lhs_args.length() {
          if lhs_args[i] != rhs_args[i] {
            match
              self.euf_asserted_equality_chain_texts(lhs_args[i], rhs_args[i]) {
              Some(chain) =>
                for premise in chain {
                  parts.push(premise)
                }
              None => return None
            }
          }
        }
        if parts.is_empty() {
          self.euf_asserted_equality_chain_texts(lhs, rhs)
        } else {
          Some(parts)
        }
      } else {
        self.euf_asserted_equality_chain_texts(lhs, rhs)
      }
    _ => self.euf_asserted_equality_chain_texts(lhs, rhs)
  }
}

///|
fn SmtContext::euf_distinct_congruence_hint(
  self : SmtContext,
  expr : @util.ExprId,
) -> String? {
  let expanded = self.manager.expand_macros(expr) catch { _ => return None }
  match self.manager.get_expr(expanded.result()).kind {
    Distinct(args) if args.length() >= 2 => {
      for i in 0..<args.length() {
        if i + 1 < args.length() {
          for j in (i + 1)..<args.length() {
            match self.euf_congruence_premise_texts(args[i], args[j]) {
              Some(parts) => {
                if parts.is_empty() {
                  parts.push(self.euf_asserted_equality_text(args[i], args[j]))
                }
                parts.push(self.manager.pretty(expr))
                return Some("congruence(\{parts.join(",")})")
              }
              None => ()
            }
          }
        }
      }
      None
    }
    _ => None
  }
}

///|
fn SmtContext::euf_negated_equality_congruence_hint(
  self : SmtContext,
  equality : @util.ExprId,
  negated : @util.ExprId,
) -> String {
  match self.manager.get_expr(equality).kind {
    Eq(lhs, rhs) => {
      let parts = match self.euf_congruence_premise_texts(lhs, rhs) {
        Some(parts) => parts
        None => [self.euf_asserted_equality_text(lhs, rhs)]
      }
      parts.push(self.manager.pretty(negated))
      "congruence(\{parts.join(",")})"
    }
    _ =>
      "congruence(\{self.manager.pretty(equality)},\{self.manager.pretty(negated)})"
  }
}

///|
fn SmtContext::euf_congruence_hint_for_assertions(self : SmtContext) -> String {
  for assertion in self.assertions.items() {
    match euf_negated_equality_inner(self.manager, assertion) {
      Some(eq) =>
        return self.euf_negated_equality_congruence_hint(eq, assertion)
      None => ()
    }
    match self.euf_distinct_congruence_hint(assertion) {
      Some(hint) => return hint
      None => ()
    }
  }
  "congruence"
}

///|
fn SmtContext::euf_congruence_hint_for_core(
  self : SmtContext,
  core : Array[@util.ExprId],
) -> String {
  for assumption in core {
    match euf_negated_equality_inner(self.manager, assumption) {
      Some(eq) =>
        return self.euf_negated_equality_congruence_hint(eq, assumption)
      None => ()
    }
    match self.euf_distinct_congruence_hint(assumption) {
      Some(hint) => return hint
      None => ()
    }
  }
  "congruence"
}

///|
fn SmtContext::proof_hint_kind_text(
  self : SmtContext,
  hint : @theory_core.ProofHintId,
) -> String {
  match self.justifications.proof_hint_kind_text(hint) {
    Some(kind) => kind
    None => "\{hint}"
  }
}

///|
fn SmtContext::theory_actions_for(
  self : SmtContext,
  theory : @theory_core.TheoryPlugin,
) -> @theory_core.TheoryActions {
  let owner = theory.name()
  @theory_core.TheoryActions::new_with_context(
    scope_depth=fn() { self.assertions.scope_depth() },
    internalize_bool=fn(expr) { self.try_internalize_bool(expr) },
    add_clause=fn(literals) {
      self.add_theory_clause(literals, owner~, redundant=false, hint=None)
    },
    add_lemma=fn(literals) {
      self.add_theory_clause(literals, owner~, redundant=true, hint=None)
    },
    add_lemma_with_hint=fn(literals, hint) {
      self.add_theory_clause(
        literals,
        owner~,
        redundant=true,
        hint=Some(self.proof_hint_kind_text(hint)),
      )
    },
    add_extension_assumption=fn(literal, expr, name) {
      self.add_extension_assumption(literal, expr, name)
    },
    enqueue=fn(literal, antecedent) {
      self.enqueue_theory_propagation(literal, antecedent)
    },
    conflict=fn(antecedent) { self.enqueue_theory_conflict(antecedent) },
    mark_unknown=fn(reason) { self.extension_unknown = Some(reason) },
    materialize_antecedent=fn(antecedent) {
      materialize_theory_antecedent(self.theories, antecedent)
    },
    create_proof_hint=fn(owner, kind) {
      self.justifications.create_proof_hint(
        owner,
        kind,
        self.assertions.scope_depth(),
      )
    },
  )
}

///|
fn SmtContext::extension_antecedent(
  self : SmtContext,
  justification : @pure_sat.ExtJustificationId,
) -> @theory_core.AntecedentId? {
  self.extension_justifications.get(justification.to_int())
}

///|
fn SmtContext::materialize_extension_antecedent(
  self : SmtContext,
  justification : @pure_sat.ExtJustificationId,
) -> Array[@pure_sat.Literal] {
  match self.extension_antecedent(justification) {
    Some(antecedent) => materialize_theory_antecedent(self.theories, antecedent)
    None => []
  }
}

///|
fn SmtContext::theory_name(
  self : SmtContext,
  owner : @theory_ids.TheoryId,
) -> String {
  match theory_plugin_by_id(self.theories, owner) {
    Some(theory) => theory.name()
    None => "\{owner}"
  }
}

///|
fn SmtContext::describe_extension_justification(
  self : SmtContext,
  justification : @pure_sat.ExtJustificationId,
) -> @pure_sat.ClauseStatus {
  match self.extension_antecedent(justification) {
    Some(antecedent) =>
      @pure_sat.Theory(self.theory_name(antecedent.owner()), true, None)
    None => @pure_sat.Redundant
  }
}

///|
fn SmtContext::dispatch_theory_asserted(
  self : SmtContext,
  literal : @pure_sat.Literal,
) -> Unit {
  let view = self.theory_view()
  let asserted = @theory_core.TheoryAssertedLiteral::new(literal)
  for theory in self.theories {
    let actions = self.theory_actions_for(theory)
    theory.asserted(view, actions, asserted)
  }
}

///|
fn SmtContext::has_extension_action(self : SmtContext) -> Bool {
  self.extension_unknown is Some(_) ||
  !self.extension_conflicts.is_empty() ||
  !self.extension_propagations.is_empty()
}

///|
fn SmtContext::next_extension_action(
  self : SmtContext,
) -> @pure_sat.ExtensionAction {
  match self.extension_unknown {
    Some(reason) => {
      self.extension_unknown = None
      @pure_sat.ExtensionUnknown(reason)
    }
    None =>
      if !self.extension_conflicts.is_empty() {
        @pure_sat.ExtensionConflict(self.extension_conflicts.remove(0))
      } else if !self.extension_propagations.is_empty() {
        let propagation = self.extension_propagations.remove(0)
        @pure_sat.ExtensionAssign(
          propagation.literal,
          propagation.justification,
        )
      } else {
        @pure_sat.ExtensionNoAction
      }
  }
}

///|
fn SmtContext::sat_extension(self : SmtContext) -> @pure_sat.SatExtension {
  @pure_sat.SatExtension::{
    init_search: fn() { @pure_sat.ExtensionNoAction },
    tracking_assumptions: fn() { self.extension_tracking_assumptions() },
    add_assumptions: fn(_) { () },
    should_research: fn(_) { false },
    can_propagate: fn() { self.has_extension_action() },
    unit_propagate: fn() { self.next_extension_action() },
    propagated: fn(_, _) { @pure_sat.KeepWatch },
    asserted: fn(literal) { self.dispatch_theory_asserted(literal) },
    is_external: fn(bool_var) {
      self.extension_assumption_var_contains(bool_var)
    },
    set_eliminated: fn(_) { () },
    get_antecedents: fn(justification) {
      self.materialize_extension_antecedent(justification)
    },
    describe_justification: fn(justification) {
      self.describe_extension_justification(justification)
    },
    check: fn(_) { self.next_extension_action() },
    reason_unknown: fn() { self.extension_unknown },
    collect_statistics: fn() { @stats.Statistics::new() },
    validate: fn(_) { @util.Available(()) },
    init_use_list: fn() { () },
    gc: fn() { () },
    gc_vars: fn(_) { () },
    is_blocked: fn(_) { false },
  }
}

///|
pub fn SmtContext::push(self : SmtContext) -> Unit {
  self.assert_new_roots() catch {
    _ => ()
  }
  self.assertions.push_scope()
  self.unsupported_terms.push_scope()
  self.egraph.push()
  self.egraph_dispatch.push()
  self.justifications.push()
  self.extension_assumptions.push_scope()
  self.internalizer.push_scope()
  self.sat_core.user_push()
  let view = self.theory_view()
  for theory in self.theories {
    theory.push(view)
  }
  self.mark_caches_stale()
}

///|
pub fn SmtContext::pop(self : SmtContext, count : Int) -> Unit {
  self.assertions.pop_scope(count) catch {
    _ => return
  }
  self.unsupported_terms.pop_scope(count) catch {
    _ => ()
  }
  self.internalizer.pop_scope(count)
  self.egraph.pop(count)
  self.egraph_dispatch.pop(count)
  self.justifications.pop(count)
  self.extension_assumptions.pop_scope(count) catch {
    _ => ()
  }
  self.sat_core.user_pop(count)
  if self.qhead > self.assertions.length() {
    self.qhead = self.assertions.length()
  }
  let view = self.theory_view()
  for theory in self.theories {
    theory.pop(view, count)
  }
  self.mark_caches_stale()
}

///|
fn SmtContext::assert_new_roots(
  self : SmtContext,
) -> Unit raise @type_error.TypeError {
  let assertions = self.assertions.items()
  while self.qhead < assertions.length() {
    let assertion = assertions[self.qhead]
    match smt_euf_assertion_route(self.manager, assertion, true) {
      EGraphAssertEuf =>
        smt_euf_enqueue_assertion_facts(
          self.manager,
          self.internalizer,
          self.egraph,
          assertion,
          true,
        )
      EGraphAssertBool => {
        let literal = self.internalizer.internalize_bool(assertion)
        ignore(self.sat_core.add_clause(@pure_sat.Clause::unit(literal)))
      }
      EGraphAssertUnsupported(reason) =>
        self.record_unsupported_term(
          assertion,
          @util.ReasonUnknown::unsupported_fragment(reason),
        )
    }
    self.qhead += 1
  }
}

///|
pub fn SmtContext::enqueue_egraph_eq(
  self : SmtContext,
  lhs : @util.ExprId,
  rhs : @util.ExprId,
) -> Unit {
  let lhs_node = self.internalizer.mk_enode(lhs)
  let rhs_node = self.internalizer.mk_enode(rhs)
  self.egraph.enqueue_new_eq(lhs_node, rhs_node)
  self.mark_caches_stale()
}

///|
pub fn SmtContext::enqueue_egraph_diseq(
  self : SmtContext,
  eq : @util.ExprId,
) -> Unit {
  self.egraph.enqueue_new_diseq(self.internalizer.mk_enode(eq))
  self.mark_caches_stale()
}

///|
pub fn SmtContext::dispatch_egraph_facts(self : SmtContext) -> Unit {
  self.egraph_dispatch.drain_new_facts(
    self.egraph,
    self.theories,
    self.theory_view(),
    fn(theory) { self.theory_actions_for(theory) },
  )
}

///|
pub fn SmtContext::egraph_eq_fact_count(self : SmtContext) -> Int {
  self.egraph_dispatch.eq_fact_count()
}

///|
pub fn SmtContext::egraph_diseq_fact_count(self : SmtContext) -> Int {
  self.egraph_dispatch.diseq_fact_count()
}

///|
pub fn SmtContext::proof_hint_log_text(self : SmtContext) -> String {
  self.justifications.proof_hint_log_text()
}

///|
pub fn SmtContext::sat_clause_event_log_text(self : SmtContext) -> String {
  self.sat_core.clause_event_log_text()
}

///|
fn SmtContext::proof_hints(self : SmtContext) -> Array[@proof.ProofHint] {
  [
    for hint in self.sat_core.clause_theory_proof_hints() => {
      @proof.ProofHint::with_owner(hint.owner_text(), hint.kind_text())
    }
  ]
}

///|
fn SmtContext::proof_assumption_scope_text(
  self : SmtContext,
  assumptions : Array[@util.ExprId],
  entries : Array[SmtUnsatCoreEntry],
) -> String? {
  let parts : Array[String] = []
  for assumption in assumptions {
    parts.push(self.manager.pretty(assumption))
  }
  for entry in entries {
    parts.push(entry.to_text())
  }
  if parts.is_empty() {
    None
  } else {
    Some(parts.join(","))
  }
}

///|
fn SmtContext::proof_root_text(self : SmtContext) -> String {
  let final_empty = if self.sat_core.has_unsat_proof_clause() {
    "true"
  } else {
    "false"
  }
  let assumptions = match self.last_proof_assumption_scope {
    Some(scope) => ";assumptions:\{scope}"
    None => ""
  }
  "sat-events:\{self.sat_clause_event_log_text()};final-empty:\{final_empty}\{assumptions};result:\{self.last_result.to_text()}"
}

///|
fn SmtContext::proof_object(self : SmtContext) -> @proof.ProofObject {
  @proof.ProofObject::from_root_and_hints(
    self.proof_root_text(),
    self.proof_hints(),
  )
}

///|
fn proof_hint_lists_equal(
  lhs : Array[@proof.ProofHint],
  rhs : Array[@proof.ProofHint],
) -> Bool {
  if lhs.length() != rhs.length() {
    return false
  }
  for i in 0..<lhs.length() {
    if lhs[i] != rhs[i] {
      return false
    }
  }
  true
}

///|
fn proof_hint_list_contains(
  hints : Array[@proof.ProofHint],
  hint : @proof.ProofHint,
) -> Bool {
  for candidate in hints {
    if candidate == hint {
      return true
    }
  }
  false
}

///|
fn proof_hint_kind_has_closed_payload(kind : String) -> Bool {
  if !kind.has_prefix("congruence(") || kind.length() <= "congruence()".length() {
    return false
  }
  let mut balance = 0
  let mut completed_arg_count = 0
  let mut saw_current_arg = false
  let mut payload_closed = false
  for char in kind {
    if payload_closed {
      if char != ' ' {
        return false
      }
    } else if char == '(' {
      if balance >= 1 {
        saw_current_arg = true
      }
      balance += 1
    } else if char == ')' {
      if balance > 1 {
        saw_current_arg = true
      }
      balance -= 1
      if balance < 0 {
        return false
      }
      if balance == 0 {
        payload_closed = true
      }
    } else if char == ',' && balance == 1 {
      if !saw_current_arg {
        return false
      }
      completed_arg_count += 1
      saw_current_arg = false
    } else if balance >= 1 && char != ' ' {
      saw_current_arg = true
    }
  }
  balance == 0 && payload_closed && completed_arg_count >= 1 && saw_current_arg
}

///|
fn proof_hint_kind_supported(kind : String) -> Bool {
  kind == "congruence" || proof_hint_kind_has_closed_payload(kind)
}

///|
fn SmtContext::proof_hint_checkers(
  self : SmtContext,
  expected_hints : Array[@proof.ProofHint],
) -> Array[@proof.ProofHintChecker] {
  let checkers : Array[@proof.ProofHintChecker] = []
  for theory in self.theories {
    let owner = theory.name()
    checkers.push(
      @proof.ProofHintChecker::new(owner, fn(hint) {
        if proof_hint_list_contains(expected_hints, hint) &&
          proof_hint_kind_supported(hint.kind_text()) {
          @util.Available(())
        } else {
          invalid_proof()
        }
      }),
    )
  }
  checkers
}

///|
fn invalid_proof() -> @util.Availability[Unit] {
  @util.Unavailable(
    @util.AvailabilityReason::unknown(@util.ReasonUnknown::InvalidProof),
  )
}

///|
fn SmtContext::check_proof_object(
  self : SmtContext,
  proof : @proof.ProofObject,
) -> @util.Availability[Unit] {
  if self.last_result != @util.ResultKind::Unsat {
    return invalid_proof()
  }
  if self.last_proof_assumption_scope is None &&
    !self.sat_core.has_unsat_proof_clause() {
    return invalid_proof()
  }
  let event_log = self.sat_clause_event_log_text()
  let expected_hints = self.proof_hints()
  if event_log == "" && expected_hints.is_empty() {
    return invalid_proof()
  }
  if self.sat_core.unhinted_theory_clause_count() > 0 {
    return invalid_proof()
  }
  let expected_root = self.proof_root_text()
  if proof.root_text() != expected_root {
    return invalid_proof()
  }
  if !proof_hint_lists_equal(proof.hints(), expected_hints) {
    return invalid_proof()
  }
  let checker = @proof.ProofObjectChecker::new(
    self.proof_hint_checkers(expected_hints),
  )
  checker.check(proof)
}

///|
fn SmtContext::run_theory_lifecycle(self : SmtContext) -> @util.ReasonUnknown? {
  if self.theories.is_empty() {
    return None
  }
  let view = self.theory_view()
  for theory in self.theories {
    let actions = self.theory_actions_for(theory)
    theory.init_search(view, actions)
  }
  self.dispatch_egraph_facts()
  let mut propagate_reason : @util.ReasonUnknown? = None
  for theory in self.theories {
    if propagate_reason is None && theory.can_propagate(view) {
      let actions = self.theory_actions_for(theory)
      match theory.propagate(view, actions) {
        @theory_core.TheoryPropagateDone => ()
        @theory_core.TheoryPropagateGiveUp(reason) =>
          propagate_reason = Some(reason)
      }
    }
  }
  let deferred_reason = match propagate_reason {
    Some(reason) => Some(reason)
    None => self.run_theory_check_rounds(view)
  }
  for theory in self.theories {
    let actions = self.theory_actions_for(theory)
    theory.finalize_check(view, actions)
  }
  for theory in self.theories {
    let actions = self.theory_actions_for(theory)
    theory.on_check_done(view, actions)
  }
  deferred_reason
}

///|
fn SmtContext::run_theory_check_rounds(
  self : SmtContext,
  view : @theory_core.TheoryContextView,
) -> @util.ReasonUnknown? {
  let mut deferred : @util.ReasonUnknown? = None
  let mut progress = true
  let mut rounds = 0
  while progress {
    progress = false
    deferred = None
    for theory in self.theories {
      let actions = self.theory_actions_for(theory)
      match theory.theory_check(view, actions) {
        @theory_core.TheoryCheckContinue => progress = true
        @theory_core.TheoryCheckDone => ()
        @theory_core.TheoryCheckGiveUp(reason) =>
          match deferred {
            Some(_) => ()
            None => deferred = Some(reason)
          }
      }
    }
    rounds += 1
    if progress && rounds > self.theories.length() + 8 {
      return Some(@util.ReasonUnknown::Other("theory-check-progress-limit"))
    }
  }
  deferred
}

///|
fn reason_from_availability_reason(
  reason : @util.AvailabilityReason,
) -> @util.ReasonUnknown {
  match reason {
    @util.UnknownReason(reason) => reason
    @util.Unsupported(reason) => reason
    @util.Disabled(feature) =>
      @util.ReasonUnknown::unsupported_fragment(feature)
    @util.NoCurrentResult => @util.ReasonUnknown::Other("no-current-result")
    @util.WrongResult(expected, actual) =>
      @util.ReasonUnknown::Other(
        "wrong-result(expected=\{expected.to_text()}, actual=\{actual.to_text()})",
      )
    @util.Stale => @util.ReasonUnknown::Other("stale")
  }
}

///|
fn SmtContext::validate_unsat_core(self : SmtContext) -> @util.ReasonUnknown? {
  let view = self.theory_view()
  for theory in self.theories {
    let actions = self.theory_actions_for(theory)
    match theory.validate_unsat_core(view, actions) {
      @util.Available(_) => ()
      @util.Unavailable(reason) =>
        return Some(reason_from_availability_reason(reason))
    }
  }
  None
}

///|
fn SmtContext::model_validation_view(
  self : SmtContext,
  model : @model.Model,
) -> @theory_core.ModelValidationView {
  @theory_core.ModelValidationView::new(eval_text=fn(expr, completion) {
    match model.eval(self.manager, expr, completion~) {
      Some(value) => Some(value.to_text())
      None => None
    }
  })
}

///|
fn model_validation_reason_from_availability_reason(
  reason : @util.AvailabilityReason,
) -> @util.ReasonUnknown {
  match reason {
    @util.UnknownReason(reason) => reason
    @util.Unsupported(reason) => reason
    @util.Disabled(_)
    | @util.NoCurrentResult
    | @util.WrongResult(_, _)
    | @util.Stale => @util.ReasonUnknown::ModelValidationFailed
  }
}

///|
fn SmtContext::validate_model(
  self : SmtContext,
  model : @model.Model,
) -> @util.ReasonUnknown? {
  let view = self.theory_view()
  let model_view = self.model_validation_view(model)
  for theory in self.theories {
    let actions = self.theory_actions_for(theory)
    match theory.validate_model(view, actions, model_view) {
      @util.Available(_) => ()
      @util.Unavailable(reason) =>
        return Some(model_validation_reason_from_availability_reason(reason))
    }
  }
  None
}

///|
fn SmtContext::model_incomplete_reason(
  self : SmtContext,
) -> @util.ReasonUnknown? {
  for theory in self.theories {
    match theory.model_incomplete_reason() {
      Some(reason) => return Some(reason)
      None => ()
    }
    if theory.has_unhandled() {
      return Some(@util.ReasonUnknown::IncompleteTheory(theory.name()))
    }
  }
  None
}

///|
fn SmtContext::run_model_lifecycle(
  self : SmtContext,
  model : @model.Model,
) -> @util.ReasonUnknown? {
  let view = self.theory_view()
  for theory in self.theories {
    let actions = self.theory_actions_for(theory)
    theory.init_model(view, actions)
  }
  for theory in self.theories {
    let actions = self.theory_actions_for(theory)
    theory.finalize_model(view, actions)
  }
  match self.model_incomplete_reason() {
    Some(reason) => return Some(reason)
    None => ()
  }
  self.validate_model(model)
}

///|
pub fn SmtContext::check_sat(self : SmtContext) -> SmtContextResult {
  self.last_proof_assumption_scope = None
  self.clear_extension_actions()
  self.assert_new_roots() catch {
    err => {
      self.last_model = None
      self.cache_stale = false
      self.last_result = @util.ResultKind::unknown_no_model()
      return SmtContextUnknown(err.to_string())
    }
  }
  match self.first_unsupported_reason() {
    Some(reason) => {
      self.last_model = None
      self.cache_stale = false
      self.last_result = @util.ResultKind::unknown_no_model()
      return SmtContextUnknown(reason.to_text())
    }
    None => ()
  }
  match
    smt_euf_check_assertions(
      self.manager,
      self.internalizer,
      self.egraph,
      self.assertions.items(),
    ) {
    EGraphEufConsistent => ()
    EGraphEufConflict => {
      self.materialize_euf_conflict_proof()
      self.last_model = None
      self.cache_stale = false
      return match self.validate_unsat_core() {
        Some(reason) => {
          self.last_result = @util.ResultKind::unknown_no_model()
          SmtContextUnknown(reason.to_text())
        }
        None => {
          self.last_result = @util.ResultKind::Unsat
          SmtContextUnsat
        }
      }
    }
    EGraphEufUnknown(reason) => {
      self.last_model = None
      self.cache_stale = false
      self.last_result = @util.ResultKind::unknown_no_model()
      return SmtContextUnknown(reason.to_text())
    }
  }
  match self.run_theory_lifecycle() {
    Some(reason) => {
      self.last_model = None
      self.cache_stale = false
      self.last_result = @util.ResultKind::unknown_no_model()
      return SmtContextUnknown(reason.to_text())
    }
    None => ()
  }
  match self.sat_core.check() {
    @pure_sat.SatCoreSat(core_model) =>
      match self.internalizer.build_model(core_model, self.theories) {
        SmtModelBuildUnknown(reason) => {
          self.last_model = None
          self.cache_stale = false
          self.last_result = @util.ResultKind::unknown_no_model()
          SmtContextUnknown(reason.to_text())
        }
        SmtModelBuildSuccess(model) =>
          match self.run_model_lifecycle(model) {
            Some(reason) => {
              self.last_model = None
              self.cache_stale = false
              self.last_result = @util.ResultKind::unknown_no_model()
              SmtContextUnknown(reason.to_text())
            }
            None => {
              self.last_model = Some(model)
              self.cache_stale = false
              self.last_result = @util.ResultKind::Sat
              SmtContextSat(model)
            }
          }
      }
    @pure_sat.SatCoreUnsat => {
      self.last_model = None
      self.cache_stale = false
      match self.validate_unsat_core() {
        Some(reason) => {
          self.last_result = @util.ResultKind::unknown_no_model()
          SmtContextUnknown(reason.to_text())
        }
        None => {
          self.last_result = @util.ResultKind::Unsat
          SmtContextUnsat
        }
      }
    }
    @pure_sat.SatCoreUnknown(reason) => {
      self.last_model = None
      self.cache_stale = false
      self.last_result = @util.ResultKind::unknown_no_model()
      SmtContextUnknown(reason)
    }
  }
}

///|
fn expr_array_contains(
  values : Array[@util.ExprId],
  value : @util.ExprId,
) -> Bool {
  for existing in values {
    if existing == value {
      return true
    }
  }
  false
}

///|
fn SmtContext::map_assumption_core(
  _self : SmtContext,
  assumptions : Array[@util.ExprId],
  literals : Array[@pure_sat.Literal],
  core : @pure_sat.AssumptionCore,
) -> Array[@util.ExprId] {
  let result : Array[@util.ExprId] = []
  for literal in core.literals() {
    for i in 0..<literals.length() {
      if literals[i] == literal {
        if !expr_array_contains(result, assumptions[i]) {
          result.push(assumptions[i])
        }
        break
      }
    }
  }
  result
}

///|
fn map_euf_assumption_core(
  assumptions : Array[@util.ExprId],
  owners : Array[@util.ExprId],
  core : Array[@util.ExprId],
) -> Array[@util.ExprId] {
  let result : Array[@util.ExprId] = []
  for assumption in core {
    for i in 0..<assumptions.length() {
      if assumptions[i] == assumption {
        if !expr_array_contains(result, owners[i]) {
          result.push(owners[i])
        }
        break
      }
    }
  }
  result
}

///|
fn SmtContext::add_bool_assumption_literal(
  self : SmtContext,
  exprs : Array[@util.ExprId],
  literals : Array[@pure_sat.Literal],
  expr : @util.ExprId,
  owner : @util.ExprId,
) -> @util.Availability[Unit] {
  let literal = self.internalizer.internalize_bool(expr) catch {
    err =>
      return @util.Unavailable(
        @util.AvailabilityReason::unknown(
          @util.ReasonUnknown::Other(err.to_string()),
        ),
      )
  }
  exprs.push(owner)
  literals.push(literal)
  @util.Available(())
}

///|
fn SmtContext::internalize_assumption_literals(
  self : SmtContext,
  assumptions : Array[@util.ExprId],
) -> @util.Availability[SmtAssumptionLiterals] {
  let exprs : Array[@util.ExprId] = []
  let literals : Array[@pure_sat.Literal] = []
  let euf_assumptions : Array[@util.ExprId] = []
  let euf_owners : Array[@util.ExprId] = []
  for assumption in assumptions {
    match smt_mixed_conjunction_parts(self.manager, assumption) {
      Some((bool_parts, euf_parts)) => {
        for part in bool_parts {
          match
            self.add_bool_assumption_literal(exprs, literals, part, assumption) {
            @util.Available(_) => ()
            @util.Unavailable(reason) => return @util.Unavailable(reason)
          }
        }
        for part in euf_parts {
          euf_assumptions.push(part)
          euf_owners.push(assumption)
        }
        continue
      }
      None => ()
    }
    match smt_euf_assertion_route(self.manager, assumption, true) {
      EGraphAssertBool =>
        match
          self.add_bool_assumption_literal(
            exprs, literals, assumption, assumption,
          ) {
          @util.Available(_) => ()
          @util.Unavailable(reason) => return @util.Unavailable(reason)
        }
      EGraphAssertEuf => {
        euf_assumptions.push(assumption)
        euf_owners.push(assumption)
      }
      EGraphAssertUnsupported(reason) =>
        return @util.Unavailable(
          @util.AvailabilityReason::unknown(@util.ReasonUnknown::Other(reason)),
        )
    }
  }
  @util.Available(SmtAssumptionLiterals::{
    exprs,
    literals,
    euf_assumptions,
    euf_owners,
  })
}

///|
fn SmtContext::assumptions_with_euf(
  self : SmtContext,
  euf_assumptions : Array[@util.ExprId],
) -> Array[@util.ExprId] {
  let result = self.assertions.items()
  for assumption in euf_assumptions {
    result.push(assumption)
  }
  result
}

///|
fn SmtContext::euf_assumptions_conflict(
  self : SmtContext,
  euf_assumptions : Array[@util.ExprId],
) -> @util.Availability[Bool] {
  match
    smt_euf_check_assertions(
      self.manager,
      self.internalizer,
      self.egraph,
      self.assumptions_with_euf(euf_assumptions),
    ) {
    EGraphEufConsistent => @util.Available(false)
    EGraphEufConflict => @util.Available(true)
    EGraphEufUnknown(reason) =>
      @util.Unavailable(@util.AvailabilityReason::unknown(reason))
  }
}

///|
fn euf_assumption_trial(
  core : Array[@util.ExprId],
  skipped : Int,
) -> Array[@util.ExprId] {
  let trial : Array[@util.ExprId] = []
  for i in 0..<core.length() {
    if i != skipped {
      trial.push(core[i])
    }
  }
  trial
}

///|
fn SmtContext::euf_assumption_core(
  self : SmtContext,
  euf_assumptions : Array[@util.ExprId],
) -> @util.Availability[Array[@util.ExprId]?] {
  if euf_assumptions.length() == 0 {
    return @util.Available(None)
  }
  match self.euf_assumptions_conflict(euf_assumptions) {
    @util.Available(false) => return @util.Available(None)
    @util.Available(true) => ()
    @util.Unavailable(reason) => return @util.Unavailable(reason)
  }
  let mut core = euf_assumptions.copy()
  let mut index = 0
  while index < core.length() {
    let trial = euf_assumption_trial(core, index)
    match self.euf_assumptions_conflict(trial) {
      @util.Available(true) => core = trial
      @util.Available(false) => index += 1
      @util.Unavailable(reason) => return @util.Unavailable(reason)
    }
  }
  @util.Available(Some(core))
}

///|
fn SmtContext::push_assumption_scope(self : SmtContext) -> Unit {
  self.egraph.push()
  self.egraph_dispatch.push()
  self.internalizer.push_scope()
  self.sat_core.user_push()
}

///|
fn SmtContext::pop_assumption_scope(self : SmtContext) -> Unit {
  self.internalizer.pop_scope(1)
  self.egraph.pop(1)
  self.egraph_dispatch.pop(1)
  self.sat_core.user_pop(1)
}

///|
pub fn SmtContext::check_sat_assuming(
  self : SmtContext,
  assumptions : Array[@util.ExprId],
) -> SmtContextAssumptionResult {
  self.last_proof_assumption_scope = None
  self.clear_extension_actions()
  self.assert_new_roots() catch {
    err => {
      self.last_model = None
      self.cache_stale = false
      self.last_result = @util.ResultKind::unknown_no_model()
      return SmtAssumptionUnknown(err.to_string())
    }
  }
  match self.first_unsupported_reason() {
    Some(reason) => {
      self.last_model = None
      self.cache_stale = false
      self.last_result = @util.ResultKind::unknown_no_model()
      return SmtAssumptionUnknown(reason.to_text())
    }
    None => ()
  }
  match
    smt_euf_check_assertions(
      self.manager,
      self.internalizer,
      self.egraph,
      self.assertions.items(),
    ) {
    EGraphEufConsistent => ()
    EGraphEufConflict => {
      self.materialize_euf_conflict_proof()
      self.last_model = None
      self.cache_stale = false
      return match self.validate_unsat_core() {
        Some(reason) => {
          self.last_result = @util.ResultKind::unknown_no_model()
          SmtAssumptionUnknown(reason.to_text())
        }
        None => {
          self.last_result = @util.ResultKind::Unsat
          SmtAssumptionUnsat([], [])
        }
      }
    }
    EGraphEufUnknown(reason) => {
      self.last_model = None
      self.cache_stale = false
      self.last_result = @util.ResultKind::unknown_no_model()
      return SmtAssumptionUnknown(reason.to_text())
    }
  }
  match self.run_theory_lifecycle() {
    Some(reason) => {
      self.last_model = None
      self.cache_stale = false
      self.last_result = @util.ResultKind::unknown_no_model()
      return SmtAssumptionUnknown(reason.to_text())
    }
    None => ()
  }
  if assumptions.is_empty() && self.extension_tracking_assumptions().is_empty() {
    match self.sat_core.check() {
      @pure_sat.SatCoreSat(core_model) =>
        return match self.internalizer.build_model(core_model, self.theories) {
          SmtModelBuildUnknown(reason) => {
            self.last_model = None
            self.cache_stale = false
            self.last_result = @util.ResultKind::unknown_no_model()
            SmtAssumptionUnknown(reason.to_text())
          }
          SmtModelBuildSuccess(model) =>
            match self.run_model_lifecycle(model) {
              Some(reason) => {
                self.last_model = None
                self.cache_stale = false
                self.last_result = @util.ResultKind::unknown_no_model()
                SmtAssumptionUnknown(reason.to_text())
              }
              None => {
                self.last_model = Some(model)
                self.cache_stale = false
                self.last_result = @util.ResultKind::Sat
                SmtAssumptionSat
              }
            }
        }
      @pure_sat.SatCoreUnsat => {
        self.last_model = None
        self.cache_stale = false
        return match self.validate_unsat_core() {
          Some(reason) => {
            self.last_result = @util.ResultKind::unknown_no_model()
            SmtAssumptionUnknown(reason.to_text())
          }
          None => {
            self.last_result = @util.ResultKind::Unsat
            SmtAssumptionUnsat([], [])
          }
        }
      }
      @pure_sat.SatCoreUnknown(reason) => {
        self.last_model = None
        self.cache_stale = false
        self.last_result = @util.ResultKind::unknown_no_model()
        return SmtAssumptionUnknown(reason)
      }
    }
  }
  self.push_assumption_scope()
  let mapping = match self.internalize_assumption_literals(assumptions) {
    @util.Available(mapping) => mapping
    @util.Unavailable(reason) => {
      self.pop_assumption_scope()
      self.last_model = None
      self.cache_stale = false
      self.last_result = @util.ResultKind::unknown_no_model()
      return SmtAssumptionUnknown(reason.to_text())
    }
  }
  match self.euf_assumption_core(mapping.euf_assumptions) {
    @util.Available(Some(core)) => {
      let unsat_assumptions = map_euf_assumption_core(
        mapping.euf_assumptions,
        mapping.euf_owners,
        core,
      )
      self.materialize_euf_conflict_proof_with_hint(
        self.euf_congruence_hint_for_core(core),
      )
      self.pop_assumption_scope()
      self.last_model = None
      self.cache_stale = false
      return match self.validate_unsat_core() {
        Some(reason) => {
          self.last_result = @util.ResultKind::unknown_no_model()
          SmtAssumptionUnknown(reason.to_text())
        }
        None => {
          self.last_result = @util.ResultKind::Unsat
          self.last_proof_assumption_scope = self.proof_assumption_scope_text(
            unsat_assumptions,
            [],
          )
          SmtAssumptionUnsat(unsat_assumptions, [])
        }
      }
    }
    @util.Available(None) => ()
    @util.Unavailable(reason) => {
      self.pop_assumption_scope()
      self.last_model = None
      self.cache_stale = false
      self.last_result = @util.ResultKind::unknown_no_model()
      return SmtAssumptionUnknown(reason.to_text())
    }
  }
  match self.sat_core.check_with_assumptions(mapping.literals) {
    @pure_sat.AssumptionSat(core_model) => {
      let build_result = self.internalizer.build_model(
        core_model,
        self.theories,
      )
      self.pop_assumption_scope()
      match build_result {
        SmtModelBuildUnknown(reason) => {
          self.last_model = None
          self.cache_stale = false
          self.last_result = @util.ResultKind::unknown_no_model()
          SmtAssumptionUnknown(reason.to_text())
        }
        SmtModelBuildSuccess(model) =>
          match self.run_model_lifecycle(model) {
            Some(reason) => {
              self.last_model = None
              self.cache_stale = false
              self.last_result = @util.ResultKind::unknown_no_model()
              SmtAssumptionUnknown(reason.to_text())
            }
            None => {
              self.last_model = Some(model)
              self.cache_stale = false
              self.last_result = @util.ResultKind::Sat
              SmtAssumptionSat
            }
          }
      }
    }
    @pure_sat.AssumptionUnsat(core) => {
      let unsat_assumptions = self.map_assumption_core(
        mapping.exprs,
        mapping.literals,
        core,
      )
      let extension_entries = self.extension_core_entries(core)
      self.pop_assumption_scope()
      self.last_model = None
      self.cache_stale = false
      match self.validate_unsat_core() {
        Some(reason) => {
          self.last_result = @util.ResultKind::unknown_no_model()
          SmtAssumptionUnknown(reason.to_text())
        }
        None => {
          self.last_result = @util.ResultKind::Unsat
          self.last_proof_assumption_scope = self.proof_assumption_scope_text(
            unsat_assumptions, extension_entries,
          )
          SmtAssumptionUnsat(unsat_assumptions, extension_entries)
        }
      }
    }
    @pure_sat.AssumptionUnknown(reason) => {
      self.pop_assumption_scope()
      self.last_model = None
      self.cache_stale = false
      self.last_result = @util.ResultKind::unknown_no_model()
      SmtAssumptionUnknown(reason)
    }
  }
}

///|
pub fn SmtContext::last_model(self : SmtContext) -> @model.Model? {
  if self.cache_stale {
    None
  } else {
    self.last_model
  }
}

///|
pub fn SmtContext::sat_core_id(_self : SmtContext) -> Int {
  1
}

///|
pub fn SmtContext::root_clause_count(self : SmtContext) -> Int {
  self.sat_core.inspect_state().root_clauses
}

///|
pub fn SmtContext::sat_var_count(self : SmtContext) -> Int {
  self.internalizer.sat_var_count()
}

///|
pub fn SmtContext::internalize_bool_text(
  self : SmtContext,
  expr : @util.ExprId,
) -> String {
  self.internalizer.expr2literal(expr).to_text() catch {
    err => "error:\{err}"
  }
}

///|
pub fn SmtContext::lookup_bool_text(
  self : SmtContext,
  expr : @util.ExprId,
) -> String {
  self.internalizer.lookup_bool_text(expr)
}

///|
pub fn SmtContext::cache_state_text(self : SmtContext) -> String {
  match self.last_model {
    Some(_) => if self.cache_stale { "model=stale" } else { "model=current" }
    None => "model=none"
  }
}

///|
fn enode_option_text(id : @egraph.EnodeId?) -> String {
  match id {
    Some(id) => "\{id}"
    None => "missing"
  }
}

///|
pub fn SmtContext::mk_enode_text(
  self : SmtContext,
  expr : @util.ExprId,
) -> String {
  "\{self.internalizer.mk_enode(expr)}"
}

///|
pub fn SmtContext::expr2enode_text(
  self : SmtContext,
  expr : @util.ExprId,
) -> String {
  enode_option_text(self.internalizer.expr2enode(expr))
}

///|
pub fn SmtContext::bool_literal2enode_text(
  self : SmtContext,
  expr : @util.ExprId,
) -> String {
  let literal = self.internalizer.internalize_bool(expr) catch {
    _ => return "missing"
  }
  enode_option_text(self.internalizer.literal2enode(literal))
}

///|
pub fn SmtContext::attach_theory_var(
  self : SmtContext,
  expr : @util.ExprId,
  theory_id : @theory_ids.TheoryId,
  theory_var : @theory_ids.TheoryVar,
) -> Unit {
  let enode = self.internalizer.mk_enode(expr)
  self.egraph.attach_theory_var(enode, theory_id, theory_var)
}

///|
pub fn SmtContext::egraph_new_eq_count(self : SmtContext) -> Int {
  self.egraph.new_eq_count()
}

///|
pub fn SmtContext::egraph_new_diseq_count(self : SmtContext) -> Int {
  self.egraph.new_diseq_count()
}
