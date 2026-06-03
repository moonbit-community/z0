///|
test "statistics_counter_accumulates_by_stable_key" {
  let stats = Statistics::new()
  stats.inc_counter("sat.decisions", 1)
  stats.inc_counter("sat.decisions", 2)
  inspect(stats.value_text("sat.decisions"), content="counter:3")
}

///|
test "statistics_timer_accumulates_by_stable_key" {
  let stats = Statistics::new()
  stats.add_timer_ms("smt.internalize.ms", 1.5)
  stats.add_timer_ms("smt.internalize.ms", 0.25)
  inspect(stats.value_text("smt.internalize.ms"), content="timer-ms:1.75")
}

///|
test "statistics_merge_combines_matching_keys" {
  let lhs = Statistics::new()
  lhs.inc_counter("sat.propagations", 3)
  let rhs = Statistics::new()
  rhs.inc_counter("sat.propagations", 4)
  lhs.merge(rhs)
  inspect(lhs.value_text("sat.propagations"), content="counter:7")
}

///|
test "statistics_keys_are_sorted_for_stable_snapshots" {
  let stats = Statistics::new()
  stats.inc_counter("z.key", 1)
  stats.inc_counter("a.key", 1)
  inspect(stats.keys_text(), content="a.key,z.key")
}

///|
test "statistics_records_solver_model_proof_query_keys" {
  let stats = Statistics::new()
  stats.record_solver_check()
  stats.record_model_query()
  stats.record_proof_query()
  inspect(
    stats.keys_text(),
    content="model.queries,proof.queries,solver.checks",
  )
  inspect(stats.value_text("model.queries"), content="counter:1")
  inspect(stats.value_text("proof.queries"), content="counter:1")
}

///|
fn stat_unit_availability_text(result : @util.Availability[Unit]) -> String {
  match result {
    @util.Available(_) => "available"
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn stat_reasons_text(reasons : Array[@util.ReasonUnknown]) -> String {
  [ for reason in reasons => reason.to_text() ].join(",")
}

///|
test "stat_manifest_rejects_incompatible_duplicate_descriptors" {
  let manifest = StatManifest::new()
  inspect(
    stat_unit_availability_text(
      manifest.add_counter(
        "sat.decisions",
        "sat",
        StatMergePolicy::sum(),
        "phase-10",
      ),
    ),
    content="available",
  )
  inspect(
    stat_unit_availability_text(
      manifest.add_counter(
        "sat.decisions",
        "sat",
        StatMergePolicy::sum(),
        "phase-10",
      ),
    ),
    content="available",
  )
  inspect(
    stat_unit_availability_text(
      manifest.add_timer_ms(
        "sat.decisions",
        "sat",
        StatMergePolicy::sum(),
        "phase-10",
      ),
    ),
    content="unsupported(stat-manifest:incompatible-key:sat.decisions)",
  )
  inspect(manifest.keys_text(), content="sat.decisions")
  inspect(manifest.owner("sat.decisions"), content="sat")
  inspect(manifest.kind_text("sat.decisions"), content="counter")
}

///|
test "statistics_manifest_reports_missing_owner_and_required_keys" {
  let manifest = StatManifest::new()
  ignore(
    manifest.add_counter(
      "solver.checks",
      "solver",
      StatMergePolicy::sum(),
      "phase-10",
    ),
  )
  let stats = Statistics::new()
  stats.inc_counter("unowned.key", 1)
  inspect(
    stat_reasons_text(stats.incomplete_reasons(manifest)),
    content="statistics-missing-owner:unowned.key,statistics-missing-required:phase-10:solver.checks",
  )
}

///|
test "statistics_merge_propagates_incomplete_reasons" {
  let manifest = StatManifest::new()
  let lhs = Statistics::new()
  lhs.mark_incomplete(@util.ReasonUnknown::IncompleteTheory("lhs"))
  let rhs = Statistics::new()
  rhs.mark_incomplete(@util.ReasonUnknown::InvalidModel)
  rhs.mark_incomplete(@util.ReasonUnknown::InvalidModel)
  lhs.merge(rhs)
  inspect(
    stat_reasons_text(lhs.incomplete_reasons(manifest)),
    content="incomplete-theory(lhs),invalid-model",
  )
}
