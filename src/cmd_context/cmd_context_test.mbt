///|
fn context_bool_expr(
  context : CommandContext,
  name : String,
) -> @util.ExprId raise {
  let decl = context.manager().lookup_decl(name).unwrap()
  context.manager().mk_app(decl, [])
}

///|
fn new_default_context() -> CommandContext {
  CommandContext::new(@assembly.solver_factory())
}

///|
fn expect_command_ok(context : CommandContext, command : Command) -> Unit raise {
  context.execute(command) catch {
    err => fail("unexpected command diagnostic: \{err}")
  }
}

///|
fn command_error_text(context : CommandContext, command : Command) -> String {
  context.execute(command) catch {
    err => return err.to_string()
  }
  "available"
}

///|
fn unavailable_unit(feature : String) -> @util.Availability[Unit] {
  @util.Unavailable(
    @util.AvailabilityReason::unsupported(
      @util.ReasonUnknown::unsupported_fragment(feature),
    ),
  )
}

///|
fn pop_rejecting_factory() -> @solver.SolverFactory {
  @solver.SolverFactory::new(fn(manager, config) {
    @solver.Solver::new(
      manager,
      config,
      @solver.SolverBackend::new(
        assert_expr=fn(_) { @util.Available(()) },
        assert_expr_tracked=fn(_, _) { @util.Available(()) },
        push=fn(_) { @util.Available(()) },
        pop=fn(_) { unavailable_unit("backend-pop") },
        check_sat_assuming=fn(_) {
          @solver.CheckSatAssumingResult::from_result(
            @solver.CheckSatResult::sat(),
          )
        },
        model=fn() { @util.Available(@model.Model::new()) },
        proof=fn() {
          @util.Unavailable(
            @util.AvailabilityReason::unsupported(
              @util.ReasonUnknown::unsupported_fragment("proof-query"),
            ),
          )
        },
        collect_statistics=fn() { @stats.Statistics::new() },
      ),
    )
  })
}

///|
fn push_rejecting_factory() -> @solver.SolverFactory {
  @solver.SolverFactory::new(fn(manager, config) {
    @solver.Solver::new(
      manager,
      config,
      @solver.SolverBackend::new(
        assert_expr=fn(_) { @util.Available(()) },
        assert_expr_tracked=fn(_, _) { @util.Available(()) },
        push=fn(_) { unavailable_unit("backend-push") },
        pop=fn(_) { @util.Available(()) },
        check_sat_assuming=fn(_) {
          @solver.CheckSatAssumingResult::from_result(
            @solver.CheckSatResult::sat(),
          )
        },
        model=fn() { @util.Available(@model.Model::new()) },
        proof=fn() {
          @util.Unavailable(
            @util.AvailabilityReason::unsupported(
              @util.ReasonUnknown::unsupported_fragment("proof-query"),
            ),
          )
        },
        collect_statistics=fn() { @stats.Statistics::new() },
      ),
    )
  })
}

///|
fn tracked_assert_rejecting_factory() -> @solver.SolverFactory {
  @solver.SolverFactory::new(fn(manager, config) {
    @solver.Solver::new(
      manager,
      config,
      @solver.SolverBackend::new(
        assert_expr=fn(_) { @util.Available(()) },
        assert_expr_tracked=fn(_, _) {
          unavailable_unit("backend-tracked-assert")
        },
        push=fn(_) { @util.Available(()) },
        pop=fn(_) { @util.Available(()) },
        check_sat_assuming=fn(_) {
          @solver.CheckSatAssumingResult::from_result(
            @solver.CheckSatResult::sat(),
          )
        },
        model=fn() { @util.Available(@model.Model::new()) },
        proof=fn() {
          @util.Unavailable(
            @util.AvailabilityReason::unsupported(
              @util.ReasonUnknown::unsupported_fragment("proof-query"),
            ),
          )
        },
        collect_statistics=fn() { @stats.Statistics::new() },
      ),
    )
  })
}

///|
fn unknown_with_model_factory() -> @solver.SolverFactory {
  @solver.SolverFactory::new(fn(manager, config) {
    @solver.Solver::new(
      manager,
      config,
      @solver.SolverBackend::new(
        assert_expr=fn(_) { @util.Available(()) },
        assert_expr_tracked=fn(_, _) { @util.Available(()) },
        push=fn(_) { @util.Available(()) },
        pop=fn(_) { @util.Available(()) },
        check_sat_assuming=fn(_) {
          @solver.CheckSatAssumingResult::from_result(
            @solver.CheckSatResult::unknown_with_model(
              @util.ReasonUnknown::Other("maybe"),
            ),
          )
        },
        model=fn() {
          let model = @model.Model::new()
          match manager.lookup_decl("p") {
            Some(p_decl) => model.add_bool_const(p_decl, "p", true)
            None => ()
          }
          @util.Available(model)
        },
        proof=fn() {
          @util.Unavailable(
            @util.AvailabilityReason::unsupported(
              @util.ReasonUnknown::unsupported_fragment("proof-query"),
            ),
          )
        },
        collect_statistics=fn() { @stats.Statistics::new() },
      ),
    )
  })
}

///|
fn unknown_unsupported_factory() -> @solver.SolverFactory {
  @solver.SolverFactory::new(fn(manager, config) {
    @solver.Solver::new(
      manager,
      config,
      @solver.SolverBackend::new(
        assert_expr=fn(_) { @util.Available(()) },
        assert_expr_tracked=fn(_, _) { @util.Available(()) },
        push=fn(_) { @util.Available(()) },
        pop=fn(_) { @util.Available(()) },
        check_sat_assuming=fn(_) {
          @solver.CheckSatAssumingResult::from_result(
            @solver.CheckSatResult::unknown_no_model(
              @util.ReasonUnknown::unsupported_fragment("quantifier"),
            ),
          )
        },
        model=fn() { @util.Available(@model.Model::new()) },
        proof=fn() {
          @util.Unavailable(
            @util.AvailabilityReason::unsupported(
              @util.ReasonUnknown::unsupported_fragment("proof-query"),
            ),
          )
        },
        collect_statistics=fn() { @stats.Statistics::new() },
      ),
    )
  })
}

///|
test "context_set_logic_qf_uf" {
  let context = new_default_context()
  expect_command_ok(context, SetLogic("QF_UF"))
  inspect(context.output(), content="")
}

///|
test "context_can_be_constructed_with_injected_solver_factory" {
  let context = CommandContext::new_with_factory(@assembly.solver_factory())
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  let p = context_bool_expr(context, "p")
  expect_command_ok(context, Assert(p))
  expect_command_ok(context, CheckSat)
  inspect(context.output(), content="sat\n")
}

///|
test "context_set_option_produce_models" {
  let context = new_default_context()
  expect_command_ok(context, SetOption(":produce-models", "true"))
  inspect(context.produce_models(), content="true")
}

///|
test "context_set_output_channels_and_resource_limit" {
  let context = new_default_context()
  expect_command_ok(context, SetOption(":diagnostic-output-channel", "stderr"))
  expect_command_ok(context, SetOption(":regular-output-channel", "stdout"))
  expect_command_ok(context, SetOption(":reproducible-resource-limit", "4"))
  inspect(context.diagnostic_output_channel(), content="stderr")
  inspect(context.regular_output_channel(), content="stdout")
  expect_command_ok(context, GetInfo(":rlimit"))
  inspect(context.output(), content="(:rlimit 1)\n")
}

///|
test "context_regular_output_channel_stderr_routes_regular_output" {
  let context = new_default_context()
  expect_command_ok(context, SetOption(":regular-output-channel", "stderr"))
  expect_command_ok(context, Echo("to-err"))
  expect_command_ok(context, CheckSat)
  inspect(context.output(), content="")
  inspect(context.stderr_output(), content="to-err\nsat\n")
}

///|
test "context_explicit_diagnostic_output_channel_stderr_routes_runner_messages" {
  let context = new_default_context()
  expect_command_ok(context, SetOption(":diagnostic-output-channel", "stderr"))
  context.append_runner_message("parse: bad command")
  inspect(context.output(), content="")
  inspect(context.stderr_output(), content="(error \"bad command\")\n")
}

///|
test "context_get_option_reports_builtin_values" {
  let context = new_default_context()
  expect_command_ok(context, GetOption(":produce-models"))
  expect_command_ok(context, GetOption(":print-warning"))
  expect_command_ok(context, GetOption(":verbosity"))
  expect_command_ok(context, GetOption(":random-seed"))
  expect_command_ok(context, GetOption(":numeral-as-real"))
  expect_command_ok(context, GetOption(":int-real-coercions"))
  expect_command_ok(context, GetOption(":error-behavior"))
  expect_command_ok(context, SetOption(":produce-models", "true"))
  expect_command_ok(context, SetOption(":global-decls", "true"))
  expect_command_ok(context, SetOption(":print-warning", "false"))
  expect_command_ok(context, SetOption(":verbosity", "3"))
  expect_command_ok(context, SetOption(":random-seed", "11"))
  expect_command_ok(context, SetOption(":numeral-as-real", "true"))
  expect_command_ok(context, SetOption(":int-real-coercions", "false"))
  expect_command_ok(context, SetOption(":error-behavior", "immediate-exit"))
  expect_command_ok(context, SetOption(":regular-output-channel", "stdout"))
  expect_command_ok(context, SetOption(":diagnostic-output-channel", "stderr"))
  expect_command_ok(context, SetOption(":reproducible-resource-limit", "40"))
  expect_command_ok(context, GetOption(":produce-models"))
  expect_command_ok(context, GetOption(":global-decls"))
  expect_command_ok(context, GetOption(":print-warning"))
  expect_command_ok(context, GetOption(":verbosity"))
  expect_command_ok(context, GetOption(":random-seed"))
  expect_command_ok(context, GetOption(":numeral-as-real"))
  expect_command_ok(context, GetOption(":int-real-coercions"))
  expect_command_ok(context, GetOption(":error-behavior"))
  expect_command_ok(context, GetOption(":regular-output-channel"))
  expect_command_ok(context, GetOption(":diagnostic-output-channel"))
  expect_command_ok(context, GetOption(":reproducible-resource-limit"))
  expect_command_ok(context, GetInfo(":error-behavior"))
  inspect(
    context.output(),
    content=(
      #|false
      #|true
      #|0
      #|0
      #|false
      #|true
      #|continued-execution
      #|true
      #|true
      #|false
      #|3
      #|11
      #|true
      #|false
      #|immediate-exit
      #|"stdout"
      #|"stderr"
      #|40
      #|(:error-behavior immediate-exit)
      #|
    ),
  )
}

///|
test "context_set_logic_rejects_after_assertion_but_not_declare_or_push" {
  let context = new_default_context()
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  expect_command_ok(context, SetLogic("QF_UF"))
  expect_command_ok(context, Reset)

  expect_command_ok(context, Push(1))
  expect_command_ok(context, SetLogic("QF_UF"))
  expect_command_ok(context, Pop(1))
  expect_command_ok(context, Reset)

  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  expect_command_ok(context, Assert(context_bool_expr(context, "p")))
  inspect(
    command_error_text(context, SetLogic("QF_UF")),
    content="solver: cannot set logic after assertions have been added",
  )
  expect_command_ok(context, CheckSat)
  inspect(context.output(), content="sat\n")
}

///|
test "context_unsupported_logic_does_not_lock_logic" {
  let context = new_default_context()
  inspect(
    command_error_text(context, SetLogic("QF_BOOL")),
    content="unsupported: unsupported logic: QF_BOOL",
  )
  expect_command_ok(context, SetLogic("QF_UF"))
  inspect(context.output(), content="")
}

///|
test "context_builtin_options_survive_reset" {
  let context = new_default_context()
  expect_command_ok(context, SetOption(":print-success", "true"))
  expect_command_ok(context, SetOption(":produce-models", "true"))
  expect_command_ok(context, SetOption(":produce-proofs", "true"))
  expect_command_ok(context, SetOption(":produce-unsat-cores", "true"))
  expect_command_ok(context, SetOption(":produce-unsat-assumptions", "true"))
  expect_command_ok(context, SetOption(":regular-output-channel", "stdout"))
  expect_command_ok(context, SetOption(":diagnostic-output-channel", "stderr"))
  expect_command_ok(context, SetOption(":verbosity", "3"))
  expect_command_ok(context, SetOption(":random-seed", "11"))
  expect_command_ok(context, SetOption(":print-warning", "false"))
  expect_command_ok(context, SetOption(":error-behavior", "immediate-exit"))
  expect_command_ok(context, Reset)
  expect_command_ok(context, GetOption(":print-success"))
  expect_command_ok(context, GetOption(":produce-models"))
  expect_command_ok(context, GetOption(":produce-proofs"))
  expect_command_ok(context, GetOption(":produce-unsat-cores"))
  expect_command_ok(context, GetOption(":produce-unsat-assumptions"))
  expect_command_ok(context, GetOption(":regular-output-channel"))
  expect_command_ok(context, GetOption(":diagnostic-output-channel"))
  expect_command_ok(context, GetOption(":verbosity"))
  expect_command_ok(context, GetOption(":random-seed"))
  expect_command_ok(context, GetOption(":print-warning"))
  expect_command_ok(context, GetOption(":error-behavior"))
  inspect(
    context.output(),
    content=(
      #|success
      #|success
      #|success
      #|success
      #|success
      #|success
      #|success
      #|success
      #|success
      #|success
      #|success
      #|success
      #|true
      #|true
      #|true
      #|true
      #|true
      #|"stdout"
      #|"stderr"
      #|3
      #|11
      #|false
      #|immediate-exit
      #|
    ),
  )
}

///|
test "context_get_info_all_statistics_uses_solver_snapshot" {
  let context = new_default_context()
  expect_command_ok(context, GetInfo(":all-statistics"))
  expect_command_ok(context, CheckSat)
  expect_command_ok(context, GetInfo(":all-statistics"))
  inspect(
    context.output(),
    content="(:all-statistics)\nsat\n(:all-statistics solver.checks)\n",
  )
}

///|
test "context_get_info_all_statistics_serializes_incomplete_reasons" {
  let factory = @solver.SolverFactory::new(fn(manager, config) {
    @solver.Solver::new(
      manager,
      config,
      @solver.SolverBackend::new(
        assert_expr=fn(_) { @util.Available(()) },
        assert_expr_tracked=fn(_, _) { @util.Available(()) },
        push=fn(_) { @util.Available(()) },
        pop=fn(_) { @util.Available(()) },
        check_sat_assuming=fn(_) {
          @solver.CheckSatAssumingResult::from_result(
            @solver.CheckSatResult::sat(),
          )
        },
        model=fn() { @util.Available(@model.Model::new()) },
        proof=fn() {
          @util.Unavailable(
            @util.AvailabilityReason::unsupported(
              @util.ReasonUnknown::unsupported_fragment("proof-query"),
            ),
          )
        },
        collect_statistics=fn() {
          let stats = @stats.Statistics::new()
          stats.inc_counter("backend.custom", 1)
          stats.mark_incomplete(@util.ReasonUnknown::IncompleteTheory("stats"))
          stats
        },
      ),
    )
  })
  let context = CommandContext::new_with_factory(factory)
  expect_command_ok(context, GetInfo(":all-statistics"))
  inspect(
    context.output(),
    content="(:all-statistics backend.custom :incomplete-reasons incomplete-theory(stats),statistics-missing-owner:backend.custom)\n",
  )
}

///|
test "context_get_info_reason_unknown_tracks_current_unknown_only" {
  let context = CommandContext::new_with_factory(unknown_unsupported_factory())
  expect_command_ok(context, GetInfo(":reason-unknown"))
  expect_command_ok(context, CheckSat)
  expect_command_ok(context, GetInfo(":reason-unknown"))
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  let p = context_bool_expr(context, "p")
  expect_command_ok(context, Assert(p))
  expect_command_ok(context, GetInfo(":reason-unknown"))
  inspect(
    context.output(),
    content=(
      #|(:reason-unknown no-current-result)
      #|unknown: unsupported-fragment(quantifier)
      #|(:reason-unknown unsupported-fragment(quantifier))
      #|(:reason-unknown stale)
      #|
    ),
  )

  let sat_context = new_default_context()
  expect_command_ok(sat_context, CheckSat)
  expect_command_ok(sat_context, GetInfo(":reason-unknown"))
  inspect(
    sat_context.output(),
    content="sat\n(:reason-unknown no-current-result)\n",
  )
}

///|
test "context_resource_limit_checkpoint_reports_exhaustion" {
  let context = new_default_context()
  expect_command_ok(context, SetOption(":reproducible-resource-limit", "1"))
  expect_command_ok(context, GetInfo(":rlimit"))
  inspect(
    command_error_text(context, CheckSat),
    content="solver: unknown(resource-limit-exceeded)",
  )
  inspect(context.output(), content="(:rlimit 1)\n")
}

///|
test "context_cancel_checkpoint_blocks_commands_until_reset" {
  let context = new_default_context()
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  let p = context_bool_expr(context, "p")
  expect_command_ok(context, Assert(p))
  expect_command_ok(context, CheckSat)
  context.cancel_api()
  inspect(context.is_canceled(), content="true")
  inspect(
    command_error_text(context, CheckSat),
    content="solver: unknown(canceled(api))",
  )
  inspect(
    command_error_text(
      context,
      DeclareConst("q", context.manager().bool_sort()),
    ),
    content="solver: unknown(canceled(api))",
  )
  inspect(context.manager().lookup_decl("q") is None, content="true")
  context.reset_cancel()
  inspect(context.is_canceled(), content="false")
  expect_command_ok(context, CheckSat)
  inspect(context.output(), content="sat\nsat\n")
}

///|
test "context_declare_and_assert_bool" {
  let context = new_default_context()
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  let p = context_bool_expr(context, "p")
  expect_command_ok(context, Assert(p))
  expect_command_ok(context, CheckSat)
  inspect(context.output(), content="sat\n")
}

///|
test "context_echo_outputs_string" {
  let context = new_default_context()
  expect_command_ok(context, Echo("hello"))
  inspect(context.output(), content="hello\n")
}

///|
test "context_exit_sets_exited_flag" {
  let context = new_default_context()
  expect_command_ok(context, Exit)
  inspect(context.exited(), content="true")
}

///|
test "context_push_pop_assertions" {
  let context = new_default_context()
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  let p = context_bool_expr(context, "p")
  let not_p = context.manager().mk_not(p)
  expect_command_ok(context, Assert(p))
  expect_command_ok(context, Push(1))
  expect_command_ok(context, Assert(not_p))
  expect_command_ok(context, CheckSat)
  expect_command_ok(context, Pop(1))
  expect_command_ok(context, CheckSat)
  inspect(context.output(), content="unsat\nsat\n")
}

///|
test "context_push_pop_removes_scoped_declaration" {
  let context = new_default_context()
  expect_command_ok(context, Push(1))
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  expect_command_ok(context, Pop(1))
  inspect(context.manager().lookup_decl("p") is None, content="true")
}

///|
test "context_global_decls_preserves_declarations_across_pop" {
  let context = new_default_context()
  expect_command_ok(context, SetOption(":global-decls", "true"))
  expect_command_ok(context, Push(1))
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  expect_command_ok(context, Pop(1))
  inspect(context.manager().lookup_decl("p") is Some(_), content="true")
  let p = context_bool_expr(context, "p")
  expect_command_ok(context, Assert(p))
  expect_command_ok(context, CheckSat)
  inspect(context.output(), content="sat\n")
}

///|
test "context_global_decls_late_set_rejected_inside_scope" {
  let context = new_default_context()
  expect_command_ok(context, Push(1))
  inspect(
    command_error_text(context, SetOption(":global-decls", "true")),
    content="solver: cannot set :global-decls while scopes are active",
  )
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  expect_command_ok(context, Pop(1))
  inspect(context.manager().lookup_decl("p") is None, content="true")
}

///|
test "context_global_declarations_alias_late_set_rejected_inside_scope" {
  let context = new_default_context()
  expect_command_ok(context, Push(1))
  inspect(
    command_error_text(context, SetOption(":global-declarations", "true")),
    content="solver: cannot set :global-decls while scopes are active",
  )
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  expect_command_ok(context, Pop(1))
  inspect(context.manager().lookup_decl("p") is None, content="true")
}

///|
test "context_global_decls_survives_reset" {
  let context = new_default_context()
  expect_command_ok(context, SetOption(":global-decls", "true"))
  expect_command_ok(context, Reset)
  expect_command_ok(context, GetOption(":global-decls"))
  expect_command_ok(context, Push(1))
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  expect_command_ok(context, Pop(1))
  inspect(context.manager().lookup_decl("p") is Some(_), content="true")
  expect_command_ok(context, Assert(context_bool_expr(context, "p")))
  expect_command_ok(context, CheckSat)
  inspect(context.output(), content="true\nsat\n")
}

///|
test "context_failed_solver_pop_preserves_ast_scope" {
  let context = CommandContext::new_with_factory(pop_rejecting_factory())
  expect_command_ok(context, Push(1))
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  inspect(
    command_error_text(context, Pop(1)),
    content="solver: unsupported(backend-pop)",
  )
  inspect(context.manager().lookup_decl("p") is Some(_), content="true")
}

///|
test "context_failed_solver_push_preserves_ast_scope" {
  let context = CommandContext::new_with_factory(push_rejecting_factory())
  inspect(
    command_error_text(context, Push(1)),
    content="solver: unsupported(backend-push)",
  )
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  inspect(command_error_text(context, Pop(1)) == "available", content="false")
  inspect(context.manager().lookup_decl("p") is Some(_), content="true")
}

///|
test "context_failed_named_assertion_does_not_create_tracker" {
  let context = new_default_context()
  let u = context.manager().declare_sort("U", 0)
  expect_command_ok(context, DeclareConst("a", u))
  let a_decl = context.manager().lookup_decl("a").unwrap()
  let a = context.manager().mk_app(a_decl, [])
  inspect(
    command_error_text(context, AssertNamed(a, "bad-tracker")) == "available",
    content="false",
  )
  inspect(context.manager().lookup_decl("bad-tracker") is None, content="true")
}

///|
test "context_failed_backend_tracked_assertion_removes_tracker" {
  let context = CommandContext::new_with_factory(
    tracked_assert_rejecting_factory(),
  )
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  let p = context_bool_expr(context, "p")
  inspect(
    command_error_text(context, AssertNamed(p, "bad-tracker")),
    content="type: unsupported(backend-tracked-assert)",
  )
  inspect(context.manager().lookup_decl("bad-tracker") is None, content="true")
}

///|
test "context_failed_solver_option_update_preserves_frontend_flags" {
  let context = new_default_context()
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  let p = context_bool_expr(context, "p")
  expect_command_ok(context, Assert(p))
  inspect(
    command_error_text(context, SetOption(":produce-proofs", "true")),
    content="solver: late-option:produce_proofs",
  )
  inspect(context.produce_proofs(), content="false")
  inspect(
    command_error_text(context, SetOption(":produce-unsat-cores", "true")),
    content="solver: late-option:produce_unsat_cores",
  )
  inspect(context.produce_unsat_cores(), content="false")
  inspect(
    command_error_text(context, SetOption(":produce-unsat-assumptions", "true")),
    content="solver: late-option:produce_unsat_assumptions",
  )
  inspect(context.produce_unsat_assumptions(), content="false")
}

///|
test "context_reset_assertions_clears_solver_and_reopens_pre_assertion_options" {
  let context = new_default_context()
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  let p = context_bool_expr(context, "p")
  let not_p = context.manager().mk_not(p)
  expect_command_ok(context, Assert(p))
  expect_command_ok(context, Assert(not_p))
  expect_command_ok(context, CheckSat)
  inspect(
    command_error_text(context, SetOption(":produce-proofs", "true")),
    content="solver: late-option:produce_proofs",
  )
  expect_command_ok(context, Push(1))
  expect_command_ok(context, ResetAssertions)
  expect_command_ok(context, CheckSat)
  expect_command_ok(context, SetOption(":produce-proofs", "true"))
  inspect(context.produce_proofs(), content="true")
  expect_command_ok(context, Assert(p))
  expect_command_ok(context, Assert(not_p))
  expect_command_ok(context, CheckSat)
  expect_command_ok(context, GetProof)
  expect_command_ok(context, Pop(1))
  inspect(context.output(), content="unsat\nsat\nunsat\nproof#0(ast)\n")
}

///|
test "context_reset_clears_declarations_logic_and_reopens_pre_assertion_options" {
  let context = new_default_context()
  expect_command_ok(context, SetLogic("QF_UF"))
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  let p = context_bool_expr(context, "p")
  let not_p = context.manager().mk_not(p)
  expect_command_ok(context, Assert(p))
  expect_command_ok(context, Assert(not_p))
  expect_command_ok(context, CheckSat)
  inspect(
    command_error_text(context, SetOption(":produce-proofs", "true")),
    content="solver: late-option:produce_proofs",
  )
  expect_command_ok(context, Reset)
  inspect(context.manager().lookup_decl("p") is None, content="true")
  expect_command_ok(context, SetLogic("QF_UF"))
  expect_command_ok(context, SetOption(":produce-proofs", "true"))
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  let reset_p = context_bool_expr(context, "p")
  let reset_not_p = context.manager().mk_not(reset_p)
  expect_command_ok(context, Assert(reset_p))
  expect_command_ok(context, Assert(reset_not_p))
  expect_command_ok(context, CheckSat)
  expect_command_ok(context, GetProof)
  inspect(context.output(), content="unsat\nunsat\nproof#0(ast)\n")
}

///|
test "context_set_info_accepts_metadata_and_print_success" {
  let context = new_default_context()
  expect_command_ok(context, SetInfo(":source", "z0"))
  expect_command_ok(context, SetOption(":print-success", "true"))
  expect_command_ok(context, SetInfo(":status", "unknown"))
  inspect(context.output(), content="success\nsuccess\n")
}

///|
test "context_define_fun_macro_is_usable" {
  let context = new_default_context()
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  let p = context_bool_expr(context, "p")
  expect_command_ok(
    context,
    DefineFun("m", [], context.manager().bool_sort(), p),
  )
  let macro_ref = context.manager().mk_macro_ref("m")
  expect_command_ok(context, Assert(macro_ref))
  expect_command_ok(context, CheckSat)
  inspect(context.output(), content="sat\n")
}

///|
test "context_get_model_requires_model_option" {
  let context = new_default_context()
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  let p = context_bool_expr(context, "p")
  expect_command_ok(context, Assert(p))
  expect_command_ok(context, CheckSat)
  expect_command_ok(context, GetModel)
  inspect(
    context.output(),
    content="sat\nerror: model production is disabled\n",
  )
}

///|
test "context_model_queries_use_unknown_with_model_candidate" {
  let context = CommandContext::new_with_factory(unknown_with_model_factory())
  expect_command_ok(context, SetOption(":produce-models", "true"))
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  let p = context_bool_expr(context, "p")
  expect_command_ok(context, CheckSat)
  expect_command_ok(context, GetModel)
  expect_command_ok(context, GetValue([ModelQueryTerm::new("p", p)]))
  expect_command_ok(context, Eval(ModelQueryTerm::new("p", p), false))
  inspect(
    context.output(),
    content=(
      #|unknown: maybe
      #|(
      #|  (define-fun p () Bool
      #|    true)
      #|)
      #|((p true))
      #|true
      #|
    ),
  )
}

///|
test "context_print_success_outputs_success" {
  let context = new_default_context()
  expect_command_ok(context, SetOption(":print-success", "true"))
  expect_command_ok(context, DeclareConst("p", context.manager().bool_sort()))
  let p = context_bool_expr(context, "p")
  expect_command_ok(context, Assert(p))
  expect_command_ok(context, Push(1))
  expect_command_ok(context, Pop(1))
  expect_command_ok(context, Exit)
  inspect(
    context.output(),
    content="success\nsuccess\nsuccess\nsuccess\nsuccess\nsuccess\n",
  )
}
