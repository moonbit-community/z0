///|
struct FakeExtensionState {
  propagated : Array[String]
  antecedents : Array[String]
  checked : Array[String]
  mut propagated_once : Bool
}

///|
fn FakeExtensionState::new() -> FakeExtensionState {
  { propagated: [], antecedents: [], checked: [], propagated_once: false }
}

///|
fn bool_option_text(value : Bool?) -> String {
  match value {
    Some(true) => "Some(true)"
    Some(false) => "Some(false)"
    None => "None"
  }
}

///|
fn positive_count_text(count : Int) -> String {
  if count > 0 {
    "queried"
  } else {
    "not-queried"
  }
}

///|
test "sat_extension_unit_propagates_with_opaque_justification" {
  let solver = SatSolverCore::new()
  let p = solver.add_var()
  let state = FakeExtensionState::new()
  solver.set_extension(SatExtension::{
    init_search: fn() { ExtensionNoAction },
    tracking_assumptions: fn() { [] },
    add_assumptions: fn(_) { () },
    should_research: fn(_) { false },
    can_propagate: fn() { !state.propagated_once },
    unit_propagate: fn() {
      state.propagated_once = true
      ExtensionAssign(Literal::pos(p), ExtJustificationId::new(7))
    },
    propagated: fn(_, _) { KeepWatch },
    asserted: fn(_) { () },
    is_external: fn(_) { false },
    set_eliminated: fn(_) { () },
    get_antecedents: fn(justification) {
      state.antecedents.push("\{justification}")
      []
    },
    describe_justification: fn(_) { Redundant },
    check: fn(_) { ExtensionNoAction },
    reason_unknown: fn() { None },
    collect_statistics: fn() { @stats.Statistics::new() },
    validate: fn(_) { @util.Available(()) },
    init_use_list: fn() { () },
    gc: fn() { () },
    gc_vars: fn(_) { () },
    is_blocked: fn(_) { false },
  })
  match solver.check() {
    SatCoreSat(model) =>
      inspect(bool_option_text(model.value(p)), content="Some(true)")
    SatCoreUnsat => inspect("unsat", content="sat")
    SatCoreUnknown(reason) => inspect(reason, content="sat")
  }
}

///|
test "sat_extension_asserted_and_external_callbacks_are_observable" {
  let solver = SatSolverCore::new()
  let p = solver.add_var()
  let external = solver.add_var()
  let asserted : Array[String] = []
  let eliminated : Array[String] = []
  let mut external_queries = 0
  solver.set_extension(SatExtension::{
    init_search: fn() { ExtensionNoAction },
    tracking_assumptions: fn() { [] },
    add_assumptions: fn(_) { () },
    should_research: fn(_) { false },
    can_propagate: fn() { false },
    unit_propagate: fn() { ExtensionNoAction },
    propagated: fn(_, _) { KeepWatch },
    asserted: fn(literal) { asserted.push("\{literal}") },
    is_external: fn(bool_var) {
      if bool_var == external {
        external_queries += 1
        true
      } else {
        false
      }
    },
    set_eliminated: fn(bool_var) { eliminated.push("\{bool_var}") },
    get_antecedents: fn(_) { [] },
    describe_justification: fn(_) { Redundant },
    check: fn(_) { ExtensionNoAction },
    reason_unknown: fn() { None },
    collect_statistics: fn() { @stats.Statistics::new() },
    validate: fn(_) { @util.Available(()) },
    init_use_list: fn() { () },
    gc: fn() { () },
    gc_vars: fn(_) { () },
    is_blocked: fn(_) { false },
  })
  ignore(solver.add_clause(Clause::unit(Literal::pos(p))))
  match solver.check() {
    SatCoreSat(model) =>
      inspect(bool_option_text(model.value(external)), content="None")
    SatCoreUnsat => inspect("unsat", content="sat")
    SatCoreUnknown(reason) => inspect(reason, content="sat")
  }
  inspect(asserted.join(","), content="b1")
  inspect(positive_count_text(external_queries), content="queried")
  inspect(eliminated.join(","), content="")
}

///|
test "sat_extension_set_eliminated_is_unreachable_when_elimination_disabled" {
  let solver = SatSolverCore::new()
  let p = solver.add_var()
  let eliminated : Array[String] = []
  solver.set_extension(SatExtension::{
    init_search: fn() { ExtensionNoAction },
    tracking_assumptions: fn() { [] },
    add_assumptions: fn(_) { () },
    should_research: fn(_) { false },
    can_propagate: fn() { false },
    unit_propagate: fn() { ExtensionNoAction },
    propagated: fn(_, _) { KeepWatch },
    asserted: fn(_) { () },
    is_external: fn(_) { false },
    set_eliminated: fn(bool_var) { eliminated.push("\{bool_var}") },
    get_antecedents: fn(_) { [] },
    describe_justification: fn(_) { Redundant },
    check: fn(_) { ExtensionNoAction },
    reason_unknown: fn() { None },
    collect_statistics: fn() { @stats.Statistics::new() },
    validate: fn(_) { @util.Available(()) },
    init_use_list: fn() { () },
    gc: fn() { () },
    gc_vars: fn(_) { () },
    is_blocked: fn(_) { false },
  })
  ignore(solver.add_clause(Clause::unit(Literal::pos(p))))
  ignore(solver.check())
  solver.user_push()
  solver.user_pop(1)
  solver.gc_vars(p)
  inspect(eliminated.join(","), content="")
}

///|
test "sat_extension_tracking_assumptions_participate_in_unsat_core" {
  let solver = SatSolverCore::new()
  let p = solver.add_var()
  let tracking = Literal::pos(p)
  let added : Array[String] = []
  let researched : Array[String] = []
  solver.set_extension(SatExtension::{
    init_search: fn() { ExtensionNoAction },
    tracking_assumptions: fn() { [tracking] },
    add_assumptions: fn(assumptions) {
      added.push("\{Clause::new(assumptions)}")
    },
    should_research: fn(core) {
      researched.push(core.text())
      false
    },
    can_propagate: fn() { false },
    unit_propagate: fn() { ExtensionNoAction },
    propagated: fn(_, _) { KeepWatch },
    asserted: fn(_) { () },
    is_external: fn(_) { false },
    set_eliminated: fn(_) { () },
    get_antecedents: fn(_) { [] },
    describe_justification: fn(_) { Redundant },
    check: fn(_) { ExtensionNoAction },
    reason_unknown: fn() { None },
    collect_statistics: fn() { @stats.Statistics::new() },
    validate: fn(_) { @util.Available(()) },
    init_use_list: fn() { () },
    gc: fn() { () },
    gc_vars: fn(_) { () },
    is_blocked: fn(_) { false },
  })
  ignore(solver.add_clause(Clause::unit(Literal::neg(p))))
  match solver.check_with_assumptions([]) {
    AssumptionUnsat(core) => inspect(core.text(), content="[b1]")
    AssumptionSat(_) => inspect("sat", content="unsat")
    AssumptionUnknown(reason) => inspect(reason, content="unsat")
  }
  inspect(added.join(","), content="[b1]")
  inspect(researched.join(","), content="[b1]")
}

///|
test "sat_extension_should_research_reloads_tracking_assumptions" {
  let solver = SatSolverCore::new()
  let p = solver.add_var()
  let q = solver.add_var()
  let mut include_q = false
  let mut research_count = 0
  let added : Array[String] = []
  solver.set_extension(SatExtension::{
    init_search: fn() { ExtensionNoAction },
    tracking_assumptions: fn() {
      if include_q {
        [Literal::pos(q)]
      } else {
        [Literal::pos(p)]
      }
    },
    add_assumptions: fn(assumptions) {
      added.push("\{Clause::new(assumptions)}")
    },
    should_research: fn(_) {
      research_count += 1
      if research_count == 1 {
        include_q = true
        true
      } else {
        false
      }
    },
    can_propagate: fn() { false },
    unit_propagate: fn() { ExtensionNoAction },
    propagated: fn(_, _) { KeepWatch },
    asserted: fn(_) { () },
    is_external: fn(_) { false },
    set_eliminated: fn(_) { () },
    get_antecedents: fn(_) { [] },
    describe_justification: fn(_) { Redundant },
    check: fn(_) { ExtensionNoAction },
    reason_unknown: fn() { None },
    collect_statistics: fn() { @stats.Statistics::new() },
    validate: fn(_) { @util.Available(()) },
    init_use_list: fn() { () },
    gc: fn() { () },
    gc_vars: fn(_) { () },
    is_blocked: fn(_) { false },
  })
  ignore(solver.add_clause(Clause::unit(Literal::neg(p))))
  ignore(solver.add_clause(Clause::unit(Literal::neg(q))))
  match solver.check_with_assumptions([]) {
    AssumptionUnsat(core) => inspect(core.text(), content="[b2]")
    AssumptionSat(_) => inspect("sat", content="unsat")
    AssumptionUnknown(reason) => inspect(reason, content="unsat")
  }
  inspect(added.join(","), content="[b1],[b2]")
}

///|
test "sat_extension_watched_constraint_keep_and_drop_callbacks" {
  let solver = SatSolverCore::new()
  let p = solver.add_var()
  let state = FakeExtensionState::new()
  solver.set_extension(SatExtension::{
    init_search: fn() { ExtensionNoAction },
    tracking_assumptions: fn() { [] },
    add_assumptions: fn(_) { () },
    should_research: fn(_) { false },
    can_propagate: fn() { false },
    unit_propagate: fn() { ExtensionNoAction },
    propagated: fn(literal, constraint) {
      state.propagated.push("\{literal}:\{constraint}")
      if constraint == ExtConstraintId::new(2) {
        DropWatch
      } else {
        KeepWatch
      }
    },
    asserted: fn(_) { () },
    is_external: fn(_) { false },
    set_eliminated: fn(_) { () },
    get_antecedents: fn(_) { [] },
    describe_justification: fn(_) { Redundant },
    check: fn(_) { ExtensionNoAction },
    reason_unknown: fn() { None },
    collect_statistics: fn() { @stats.Statistics::new() },
    validate: fn(_) { @util.Available(()) },
    init_use_list: fn() { () },
    gc: fn() { () },
    gc_vars: fn(_) { () },
    is_blocked: fn(_) { false },
  })
  solver.watch_external(Literal::pos(p), ExtConstraintId::new(1))
  solver.watch_external(Literal::pos(p), ExtConstraintId::new(2))
  ignore(solver.add_clause(Clause::unit(Literal::pos(p))))
  inspect(result_text(solver.check()), content="sat")
  inspect(
    state.propagated.join(","),
    content="b1:ext-constraint#1,b1:ext-constraint#2",
  )
  inspect(solver.external_watch_count(), content="1")
}

///|
test "sat_extension_conflict_materializes_opaque_antecedents" {
  let solver = SatSolverCore::new()
  let p = solver.add_var()
  let state = FakeExtensionState::new()
  solver.set_extension(SatExtension::{
    init_search: fn() { ExtensionNoAction },
    tracking_assumptions: fn() { [] },
    add_assumptions: fn(_) { () },
    should_research: fn(_) { false },
    can_propagate: fn() { false },
    unit_propagate: fn() { ExtensionNoAction },
    propagated: fn(_, _) { KeepWatch },
    asserted: fn(_) { () },
    is_external: fn(_) { false },
    set_eliminated: fn(_) { () },
    get_antecedents: fn(justification) {
      state.antecedents.push("\{justification}")
      [Literal::pos(p)]
    },
    describe_justification: fn(_) { Redundant },
    check: fn(_) { ExtensionConflict(ExtJustificationId::new(3)) },
    reason_unknown: fn() { None },
    collect_statistics: fn() { @stats.Statistics::new() },
    validate: fn(_) { @util.Available(()) },
    init_use_list: fn() { () },
    gc: fn() { () },
    gc_vars: fn(_) { () },
    is_blocked: fn(_) { false },
  })
  ignore(solver.add_clause(Clause::unit(Literal::neg(p))))
  inspect(result_text(solver.check()), content="unsat")
  inspect(state.antecedents.join(","), content="ext-justification#3")
}

///|
test "sat_extension_check_model_observes_assignment_and_backtracks" {
  let solver = SatSolverCore::new()
  let p = solver.add_var()
  let state = FakeExtensionState::new()
  solver.set_extension(SatExtension::{
    init_search: fn() { ExtensionNoAction },
    tracking_assumptions: fn() { [] },
    add_assumptions: fn(_) { () },
    should_research: fn(_) { false },
    can_propagate: fn() { false },
    unit_propagate: fn() { ExtensionNoAction },
    propagated: fn(_, _) { KeepWatch },
    asserted: fn(_) { () },
    is_external: fn(_) { false },
    set_eliminated: fn(_) { () },
    get_antecedents: fn(justification) {
      state.antecedents.push("\{justification}")
      [Literal::pos(p)]
    },
    describe_justification: fn(_) {
      Theory("model-check", true, Some("reject-false"))
    },
    check: fn(model) {
      let value = bool_option_text(model.value(p))
      state.checked.push(value)
      if value == "Some(false)" {
        ExtensionConflict(ExtJustificationId::new(11))
      } else {
        ExtensionNoAction
      }
    },
    reason_unknown: fn() { None },
    collect_statistics: fn() { @stats.Statistics::new() },
    validate: fn(_) { @util.Available(()) },
    init_use_list: fn() { () },
    gc: fn() { () },
    gc_vars: fn(_) { () },
    is_blocked: fn(_) { false },
  })
  match solver.check() {
    SatCoreSat(model) => {
      inspect(bool_option_text(model.value(p)), content="Some(true)")
      inspect(state.checked.join(">"), content="Some(false)>Some(true)")
      inspect(state.antecedents.join(","), content="ext-justification#11")
    }
    SatCoreUnsat => inspect("unsat", content="sat")
    SatCoreUnknown(reason) => inspect(reason, content="sat")
  }
}

///|
test "sat_extension_conflicting_propagation_learns_theory_clause" {
  let solver = SatSolverCore::new()
  let p = solver.add_var()
  let state = FakeExtensionState::new()
  solver.set_extension(SatExtension::{
    init_search: fn() { ExtensionNoAction },
    tracking_assumptions: fn() { [] },
    add_assumptions: fn(_) { () },
    should_research: fn(_) { false },
    can_propagate: fn() { !state.propagated_once },
    unit_propagate: fn() {
      state.propagated_once = true
      ExtensionAssign(Literal::pos(p), ExtJustificationId::new(9))
    },
    propagated: fn(_, _) { KeepWatch },
    asserted: fn(_) { () },
    is_external: fn(_) { false },
    set_eliminated: fn(_) { () },
    get_antecedents: fn(justification) {
      state.antecedents.push("\{justification}")
      [Literal::pos(p)]
    },
    describe_justification: fn(_) {
      Theory("fake-euf", true, Some("congruence"))
    },
    check: fn(_) { ExtensionNoAction },
    reason_unknown: fn() { None },
    collect_statistics: fn() { @stats.Statistics::new() },
    validate: fn(_) { @util.Available(()) },
    init_use_list: fn() { () },
    gc: fn() { () },
    gc_vars: fn(_) { () },
    is_blocked: fn(_) { false },
  })
  ignore(solver.add_clause(Clause::unit(Literal::neg(p))))
  inspect(result_text(solver.check()), content="unsat")
  inspect(state.antecedents.join(","), content="ext-justification#9")
  inspect(solver.inspect_state().learned_clauses, content="1")
  inspect(
    solver.clause_event_log_text(),
    content=(
      #|add clause#0 asserted input;add clause#1 theory fake-euf redundant hint congruence
    ),
  )
}

///|
test "sat_extension_reason_unknown_is_typed" {
  let solver = SatSolverCore::new()
  solver.set_extension(SatExtension::{
    init_search: fn() { ExtensionNoAction },
    tracking_assumptions: fn() { [] },
    add_assumptions: fn(_) { () },
    should_research: fn(_) { false },
    can_propagate: fn() { false },
    unit_propagate: fn() { ExtensionNoAction },
    propagated: fn(_, _) { KeepWatch },
    asserted: fn(_) { () },
    is_external: fn(_) { false },
    set_eliminated: fn(_) { () },
    get_antecedents: fn(_) { [] },
    describe_justification: fn(_) { Redundant },
    check: fn(_) {
      ExtensionUnknown(@util.ReasonUnknown::IncompleteTheory("fake"))
    },
    reason_unknown: fn() { Some(@util.ReasonUnknown::IncompleteTheory("fake")) },
    collect_statistics: fn() { @stats.Statistics::new() },
    validate: fn(_) { @util.Available(()) },
    init_use_list: fn() { () },
    gc: fn() { () },
    gc_vars: fn(_) { () },
    is_blocked: fn(_) { false },
  })
  inspect(
    result_text(solver.check()),
    content="unknown:incomplete-theory(fake)",
  )
}

///|
test "sat_extension_collect_statistics_merges_with_core_statistics" {
  let solver = SatSolverCore::new()
  let p = solver.add_var()
  ignore(solver.add_clause(Clause::unit(Literal::pos(p))))
  solver.set_extension(SatExtension::{
    init_search: fn() { ExtensionNoAction },
    tracking_assumptions: fn() { [] },
    add_assumptions: fn(_) { () },
    should_research: fn(_) { false },
    can_propagate: fn() { false },
    unit_propagate: fn() { ExtensionNoAction },
    propagated: fn(_, _) { KeepWatch },
    asserted: fn(_) { () },
    is_external: fn(_) { false },
    set_eliminated: fn(_) { () },
    get_antecedents: fn(_) { [] },
    describe_justification: fn(_) { Redundant },
    check: fn(_) { ExtensionNoAction },
    reason_unknown: fn() { None },
    collect_statistics: fn() {
      let statistics = @stats.Statistics::new()
      statistics.inc_counter("sat.extension.fake.events", 3)
      statistics
    },
    validate: fn(_) { @util.Available(()) },
    init_use_list: fn() { () },
    gc: fn() { () },
    gc_vars: fn(_) { () },
    is_blocked: fn(_) { false },
  })
  inspect(result_text(solver.check()), content="sat")
  let statistics = solver.collect_statistics()
  inspect(statistics.value_text("sat.core.vars"), content="counter:1")
  inspect(
    statistics.value_text("sat.extension.fake.events"),
    content="counter:3",
  )
}

///|
test "sat_extension_no_extension_statistics_are_noop" {
  let solver = SatSolverCore::new()
  solver.set_extension(SatExtension::no_extension())
  inspect(
    solver.collect_statistics().value_text("sat.extension.fake.events"),
    content="missing",
  )
}

///|
test "sat_extension_validate_failure_maps_to_unknown_reason" {
  let solver = SatSolverCore::new()
  solver.set_extension(SatExtension::{
    init_search: fn() { ExtensionNoAction },
    tracking_assumptions: fn() { [] },
    add_assumptions: fn(_) { () },
    should_research: fn(_) { false },
    can_propagate: fn() { false },
    unit_propagate: fn() { ExtensionNoAction },
    propagated: fn(_, _) { KeepWatch },
    asserted: fn(_) { () },
    is_external: fn(_) { false },
    set_eliminated: fn(_) { () },
    get_antecedents: fn(_) { [] },
    describe_justification: fn(_) { Redundant },
    check: fn(_) { ExtensionNoAction },
    reason_unknown: fn() { None },
    collect_statistics: fn() { @stats.Statistics::new() },
    validate: fn(_) {
      @util.Unavailable(
        @util.AvailabilityReason::unknown(
          @util.ReasonUnknown::ModelValidationFailed,
        ),
      )
    },
    init_use_list: fn() { () },
    gc: fn() { () },
    gc_vars: fn(_) { () },
    is_blocked: fn(_) { false },
  })
  inspect(
    result_text(solver.check()),
    content="unknown:model-validation-failed",
  )
}

///|
test "sat_extension_gc_use_list_hooks_are_deterministic" {
  let solver = SatSolverCore::new()
  let p = solver.add_var()
  let events : Array[String] = []
  solver.set_extension(SatExtension::{
    init_search: fn() { ExtensionNoAction },
    tracking_assumptions: fn() { [] },
    add_assumptions: fn(_) { () },
    should_research: fn(_) { false },
    can_propagate: fn() { false },
    unit_propagate: fn() { ExtensionNoAction },
    propagated: fn(_, _) { KeepWatch },
    asserted: fn(_) { () },
    is_external: fn(_) { false },
    set_eliminated: fn(_) { () },
    get_antecedents: fn(_) { [] },
    describe_justification: fn(_) { Redundant },
    check: fn(_) { ExtensionNoAction },
    reason_unknown: fn() { None },
    collect_statistics: fn() { @stats.Statistics::new() },
    validate: fn(_) { @util.Available(()) },
    init_use_list: fn() { events.push("init-use-list") },
    gc: fn() { events.push("gc") },
    gc_vars: fn(max_var) { events.push("gc-vars:\{max_var}") },
    is_blocked: fn(constraint) {
      events.push("is-blocked:\{constraint}")
      constraint == ExtConstraintId::new(2)
    },
  })
  solver.watch_external(Literal::pos(p), ExtConstraintId::new(1))
  solver.watch_external(Literal::pos(p), ExtConstraintId::new(2))
  inspect(solver.external_watch_count(), content="1")
  solver.gc_vars(p)
  solver.gc()
  inspect(
    events.join(","),
    content=(
      #|init-use-list,is-blocked:ext-constraint#1,is-blocked:ext-constraint#2,gc-vars:b1,gc
    ),
  )
  let no_extension = SatSolverCore::new()
  let q = no_extension.add_var()
  no_extension.set_extension(SatExtension::no_extension())
  no_extension.watch_external(Literal::pos(q), ExtConstraintId::new(3))
  no_extension.gc_vars(q)
  no_extension.gc()
  inspect(no_extension.external_watch_count(), content="1")
}

///|
test "sat_core_proof_status_hook_is_sat_local" {
  let hook = SatProofStatusHook::new()
  hook.clause_added(ClauseId::new(4), Redundant)
  hook.result(SatCoreUnsat)
  inspect(
    hook.events_text(),
    content="add clause#4 redundant learned;result unsat",
  )
}
