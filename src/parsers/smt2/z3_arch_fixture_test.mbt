///|
struct Z3ArchManifestEntry {
  id : String
  input_file : String
  expected_stdout : String
  expected_stderr : String
  expected_exit_code : String
  runner_modes : String
  command_count : String
  command_kind : String
  support_status : String
  syntax_family : String
  reject_stage : String
  status_category : String
  reason_unknown : String
  diagnostic : String
  z3_expected : String
  z3_diff_reason : String
  allow_unsupported : Bool
  allow_unknown : Bool
  normalization : String
}

///|
fn z3_arch_unavailable_proof() -> @util.Availability[@proof.ProofRef] {
  @util.Unavailable(
    @util.AvailabilityReason::unsupported(
      @util.ReasonUnknown::unsupported_fragment("proof-query"),
    ),
  )
}

///|
fn z3_arch_model_with_declared_p(manager : @ast.AstManager) -> @model.Model {
  let model = @model.Model::new()
  match manager.lookup_decl("p") {
    Some(p_decl) => model.add_bool_const(p_decl, "p", true)
    None => ()
  }
  model
}

///|
fn z3_arch_unknown_factory(
  result : @solver.CheckSatResult,
  model_with_declared_p : Bool,
) -> @solver.SolverFactory {
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
          @solver.CheckSatAssumingResult::from_result(result)
        },
        model=fn() {
          if model_with_declared_p {
            @util.Available(z3_arch_model_with_declared_p(manager))
          } else {
            @util.Available(@model.Model::new())
          }
        },
        proof=fn() { z3_arch_unavailable_proof() },
        collect_statistics=fn() { @stats.Statistics::new() },
      ),
    )
  })
}

///|
fn z3_arch_statistics_incomplete_factory() -> @solver.SolverFactory {
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
            @solver.CheckSatResult::sat(),
          )
        },
        model=fn() { @util.Available(@model.Model::new()) },
        proof=fn() { z3_arch_unavailable_proof() },
        collect_statistics=fn() {
          let stats = @stats.Statistics::new()
          stats.inc_counter("backend.custom", 1)
          stats.mark_incomplete(@util.ReasonUnknown::IncompleteTheory("stats"))
          stats
        },
      ),
    )
  })
}

///|
fn z3_arch_fixture_factory(id : String) -> @solver.SolverFactory {
  match id {
    "z3_arch_custom_statistics_incomplete" =>
      z3_arch_statistics_incomplete_factory()
    "z3_arch_custom_statistics_schema" =>
      z3_arch_statistics_incomplete_factory()
    "z3_arch_custom_unknown_with_model" =>
      z3_arch_unknown_factory(
        @solver.CheckSatResult::unknown_with_model(
          @util.ReasonUnknown::Other("maybe"),
        ),
        true,
      )
    "z3_arch_custom_unknown_no_model" =>
      z3_arch_unknown_factory(
        @solver.CheckSatResult::unknown_no_model(
          @util.ReasonUnknown::Other("maybe"),
        ),
        false,
      )
    "z3_arch_custom_timeout_reason" =>
      z3_arch_unknown_factory(
        @solver.CheckSatResult::unknown_no_model(@util.ReasonUnknown::Timeout),
        false,
      )
    "z3_arch_custom_memout_reason" =>
      z3_arch_unknown_factory(
        @solver.CheckSatResult::unknown_no_model(@util.ReasonUnknown::Memout),
        false,
      )
    "z3_arch_custom_max_conflicts_reason" =>
      z3_arch_unknown_factory(
        @solver.CheckSatResult::unknown_no_model(
          @util.ReasonUnknown::MaxConflictsReached,
        ),
        false,
      )
    "z3_arch_custom_resource_limit_reason" =>
      z3_arch_unknown_factory(
        @solver.CheckSatResult::unknown_no_model(
          @util.ReasonUnknown::ResourceLimitExceeded,
        ),
        false,
      )
    "z3_arch_custom_canceled_reason" =>
      z3_arch_unknown_factory(
        @solver.CheckSatResult::unknown_no_model(
          @util.ReasonUnknown::canceled("api"),
        ),
        false,
      )
    "z3_arch_custom_unsupported_fragment_reason" =>
      z3_arch_unknown_factory(
        @solver.CheckSatResult::unknown_no_model(
          @util.ReasonUnknown::unsupported_fragment("array"),
        ),
        false,
      )
    "z3_arch_custom_invalid_core_reason" =>
      z3_arch_unknown_factory(
        @solver.CheckSatResult::unknown_no_model(
          @util.ReasonUnknown::InvalidCore,
        ),
        false,
      )
    "z3_arch_custom_invalid_proof_reason" =>
      z3_arch_unknown_factory(
        @solver.CheckSatResult::unknown_no_model(
          @util.ReasonUnknown::InvalidProof,
        ),
        false,
      )
    "z3_arch_custom_invalid_model_reason" =>
      z3_arch_unknown_factory(
        @solver.CheckSatResult::unknown_no_model(
          @util.ReasonUnknown::InvalidModel,
        ),
        false,
      )
    "z3_arch_custom_incomplete_theory_reason" =>
      z3_arch_unknown_factory(
        @solver.CheckSatResult::unknown_no_model(
          @util.ReasonUnknown::IncompleteTheory("fake"),
        ),
        false,
      )
    "z3_arch_custom_incomplete_quantifiers_reason" =>
      z3_arch_unknown_factory(
        @solver.CheckSatResult::unknown_no_model(
          @util.ReasonUnknown::IncompleteQuantifiers,
        ),
        false,
      )
    "z3_arch_custom_incomplete_lambdas_reason" =>
      z3_arch_unknown_factory(
        @solver.CheckSatResult::unknown_no_model(
          @util.ReasonUnknown::IncompleteLambdas,
        ),
        false,
      )
    _ => @assembly.solver_factory()
  }
}

///|
fn z3_arch_manifest_text() -> String {
  (
    #|id|input_file|expected_stdout|expected_stderr|expected_exit_code|runner_modes|command_count|command_kind|support_status|syntax_family|reject_stage|status_category|reason_unknown|diagnostic|z3_expected|z3_diff_reason|allow_unsupported|allow_unknown|normalization
    #|z3_arch_bool_incremental|smt2/z3_arch_bool_incremental.smt2|smt2/z3_arch_bool_incremental.expected.out||0|parser-runner,file-shell,interactive-shell|8|incremental|supported-success|Bool|none|sat-after-pop|none|none|same|none|false|false|exact
    #|z3_arch_assumptions_core|smt2/z3_arch_assumptions_core.smt2|smt2/z3_arch_assumptions_core.expected.out||0|parser-runner,file-shell,interactive-shell|5|assumptions-core|supported-success|Bool|none|unsat-assumptions|none|none|same|none|false|false|exact
    #|z3_arch_let_bool|smt2/z3_arch_let_bool.smt2|smt2/z3_arch_let_bool.expected.out||0|parser-runner,file-shell,interactive-shell|4|let-bool|supported-success|Bool|none|let-bool-unsat|none|none|same|none|false|false|exact
    #|z3_arch_let_euf|smt2/z3_arch_let_euf.smt2|smt2/z3_arch_let_euf.expected.out||0|parser-runner,file-shell,interactive-shell|7|let-euf|supported-success|EUF|none|let-euf-unsat|none|none|same|none|false|false|exact
    #|z3_arch_define_fun_bool|smt2/z3_arch_define_fun_bool.smt2|smt2/z3_arch_define_fun_bool.expected.out||0|parser-runner,file-shell,interactive-shell|5|define-fun-bool|supported-success|Bool|none|define-fun-bool-macro|none|none|same|none|false|false|exact
    #|z3_arch_model_eval|smt2/z3_arch_model_eval.smt2|smt2/z3_arch_model_eval.expected.out||0|parser-runner,file-shell,interactive-shell|7|model-eval|supported-success|Bool|none|sat-model-value-eval|none|none|same|none|false|false|exact
    #|z3_arch_eval_completion|smt2/z3_arch_eval_completion.smt2|smt2/z3_arch_eval_completion.expected.out||0|parser-runner,file-shell,interactive-shell|6|eval-completion|supported-success|EUF|none|eval-completion-false-true|none|error:model-eval-failed|different|z0-eval-completion-default-fails-partial-uf|false|false|exact
    #|z3_arch_eval_availability|smt2/z3_arch_eval_availability.smt2|smt2/z3_arch_eval_availability.expected.out||0|parser-runner,file-shell,interactive-shell|7|eval-availability|supported-success|Bool|none|eval-disabled-no-current-success|no-current-result|error:model-production-disabled|different|z0-eval-availability-text|false|false|exact
    #|z3_arch_model_query_availability|smt2/z3_arch_model_query_availability.smt2|smt2/z3_arch_model_query_availability.expected.out||0|parser-runner,file-shell,interactive-shell|7|model-query-availability|supported-success|EUF|none|model-query-unavailable|no-current-result|error:model-value-eval-unavailable|different|z0-model-eval-unavailable-text|false|false|exact
    #|z3_arch_model_query_stale|smt2/z3_arch_model_query_stale.smt2|smt2/z3_arch_model_query_stale.expected.out||0|parser-runner,file-shell,interactive-shell|11|model-query-stale|supported-success|Bool|none|model-query-stale|stale|error:model-value-eval-stale|different|z0-stale-query-text|false|false|exact
    #|z3_arch_model_repeated_scoped|smt2/z3_arch_model_repeated_scoped.smt2|smt2/z3_arch_model_repeated_scoped.expected.out||0|parser-runner,file-shell,interactive-shell|12|model-repeated-scoped|supported-success|Bool|none|multiple-model-queries-scopes|none|none|same|none|false|false|exact
    #|z3_arch_model_euf_constants|smt2/z3_arch_model_euf_constants.smt2|smt2/z3_arch_model_euf_constants.expected.out||0|parser-runner,file-shell,interactive-shell|8|model-euf-constants|supported-success|EUF|none|model-universe-constants|none|none|different|z0-model-universe-format|false|false|exact
    #|z3_arch_model_partial_unary_uf|smt2/z3_arch_model_partial_unary_uf.smt2|smt2/z3_arch_model_partial_unary_uf.expected.out||0|parser-runner,file-shell,interactive-shell|9|model-partial-unary-uf|supported-success|EUF|none|model-partial-function|none|none|different|z0-uses-unspecified-default|false|false|exact
    #|z3_arch_get_value_partial_uf_completion|smt2/z3_arch_get_value_partial_uf_completion.smt2|smt2/z3_arch_get_value_partial_uf_completion.expected.out||0|parser-runner,file-shell,interactive-shell|10|get-value-partial-uf-completion|supported-success|EUF|none|get-value-completion|none|none|different|z0-completes-undefined-uf-application|false|false|exact
    #|z3_arch_proof_modes|smt2/z3_arch_proof_modes.smt2|smt2/z3_arch_proof_modes.expected.out||0|parser-runner,file-shell,interactive-shell|12|proof-modes|supported-success|Bool|none|proof-disabled-enabled|none|none|different|z0-uses-proof-skeleton-text|false|false|exact
    #|z3_arch_proof_availability|smt2/z3_arch_proof_availability.smt2|smt2/z3_arch_proof_availability.expected.out||0|parser-runner,file-shell,interactive-shell|8|proof-availability|supported-success|Bool|none|proof-no-current-wrong-stale|no-current-result/wrong-result/stale|error:proof-unavailable|different|z0-proof-availability-text|false|false|exact
    #|z3_arch_unsat_query_availability|smt2/z3_arch_unsat_query_availability.smt2|smt2/z3_arch_unsat_query_availability.expected.out||0|parser-runner,file-shell,interactive-shell|12|unsat-query-availability|supported-success|Bool|none|unsat-query-no-current-wrong-stale|no-current-result/wrong-result/stale|error:unsat-query-unavailable|different|z0-unsat-query-availability-text|false|false|exact
    #|z3_arch_unknown_unsupported|smt2/z3_arch_unknown_unsupported.smt2|smt2/z3_arch_unknown_unsupported.expected.out||0|parser-runner,file-shell,interactive-shell|5|unsupported-fragment|explicit-unsupported|quantifier|parser|unsupported-fragment|unsupported-fragment|unsupported:quantifiers|different|phase-limited-quantifiers|true|false|exact
    #|z3_arch_unsupported_array_sort|smt2/z3_arch_unsupported_array_sort.smt2|smt2/z3_arch_unsupported_array_sort.expected.out||0|parser-runner,file-shell,interactive-shell|1|unsupported-array-sort|explicit-unsupported|array|sort-check|unsupported-fragment|unsupported-fragment|unsupported:arrays|different|phase-limited-arrays|true|false|exact
    #|z3_arch_unsupported_array_select_store|smt2/z3_arch_unsupported_array_select_store.smt2|smt2/z3_arch_unsupported_array_select_store.expected.out||0|parser-runner,file-shell,interactive-shell|1|unsupported-array-select-store|explicit-unsupported|array|parser|unsupported-fragment|unsupported-fragment|unsupported:arrays|different|z0-reserves-array-operators-before-uf-lookup|true|false|exact
    #|z3_arch_unsupported_bv_sort|smt2/z3_arch_unsupported_bv_sort.smt2|smt2/z3_arch_unsupported_bv_sort.expected.out||0|parser-runner,file-shell,interactive-shell|1|unsupported-bv-sort|explicit-unsupported|bv|sort-check|unsupported-fragment|unsupported-fragment|unsupported:bit-vectors|different|phase-limited-bit-vectors|true|false|exact
    #|z3_arch_unsupported_bv_literal|smt2/z3_arch_unsupported_bv_literal.smt2|smt2/z3_arch_unsupported_bv_literal.expected.out||0|parser-runner,file-shell,interactive-shell|1|unsupported-bv-literal|explicit-unsupported|bv|parser|unsupported-fragment|unsupported-fragment|unsupported:bit-vectors|different|phase-limited-bit-vectors|true|false|exact
    #|z3_arch_unsupported_bv_indexed_op|smt2/z3_arch_unsupported_bv_indexed_op.smt2|smt2/z3_arch_unsupported_bv_indexed_op.expected.out||0|parser-runner,file-shell,interactive-shell|1|unsupported-bv-indexed-op|explicit-unsupported|bv|parser|unsupported-fragment|unsupported-fragment|unsupported:bit-vectors|different|phase-limited-bit-vectors|true|false|exact
    #|z3_arch_unsupported_datatype_decl|smt2/z3_arch_unsupported_datatype_decl.smt2|smt2/z3_arch_unsupported_datatype_decl.expected.out||0|parser-runner,file-shell,interactive-shell|1|unsupported-datatype-decl|explicit-unsupported|datatype|parser|unsupported-fragment|unsupported-fragment|unsupported:datatypes|different|phase-limited-datatypes|true|false|exact
    #|z3_arch_unsupported_datatype_constructor|smt2/z3_arch_unsupported_datatype_constructor.smt2|smt2/z3_arch_unsupported_datatype_constructor.expected.out||0|parser-runner,file-shell,interactive-shell|1|unsupported-datatype-constructor|explicit-unsupported|datatype|parser|unsupported-fragment|unsupported-fragment|unsupported:datatypes|different|phase-limited-datatypes|true|false|exact
    #|z3_arch_unsupported_datatype_match|smt2/z3_arch_unsupported_datatype_match.smt2|smt2/z3_arch_unsupported_datatype_match.expected.out||0|parser-runner,file-shell,interactive-shell|1|unsupported-datatype-match|explicit-unsupported|datatype|parser|unsupported-fragment|unsupported-fragment|unsupported:datatypes|different|phase-limited-datatypes|true|false|exact
    #|z3_arch_unsupported_string_sort|smt2/z3_arch_unsupported_string_sort.smt2|smt2/z3_arch_unsupported_string_sort.expected.out||0|parser-runner,file-shell,interactive-shell|1|unsupported-string-sort|explicit-unsupported|seq|sort-check|unsupported-fragment|unsupported-fragment|unsupported:strings|different|phase-limited-seq-strings|true|false|exact
    #|z3_arch_unsupported_string_literal|smt2/z3_arch_unsupported_string_literal.smt2|smt2/z3_arch_unsupported_string_literal.expected.out||0|parser-runner,file-shell,interactive-shell|1|unsupported-string-literal|explicit-unsupported|seq|parser|unsupported-fragment|unsupported-fragment|unsupported:strings|different|phase-limited-seq-strings|true|false|exact
    #|z3_arch_unsupported_seq_op|smt2/z3_arch_unsupported_seq_op.smt2|smt2/z3_arch_unsupported_seq_op.expected.out||0|parser-runner,file-shell,interactive-shell|1|unsupported-seq-op|explicit-unsupported|seq|parser|unsupported-fragment|unsupported-fragment|unsupported:strings|different|phase-limited-seq-strings|true|false|exact
    #|z3_arch_unsupported_exists|smt2/z3_arch_unsupported_exists.smt2|smt2/z3_arch_unsupported_exists.expected.out||0|parser-runner,file-shell,interactive-shell|4|unsupported-exists|explicit-unsupported|quantifier|parser|unsupported-fragment|unsupported-fragment|unsupported:quantifiers|different|phase-limited-quantifiers|true|false|exact
    #|z3_arch_unsupported_reserved_identifier|smt2/z3_arch_unsupported_reserved_identifier.smt2|smt2/z3_arch_unsupported_reserved_identifier.expected.out||0|parser-runner,file-shell,interactive-shell|1|unsupported-reserved-identifier|explicit-unsupported|reserved|parser|unsupported-fragment|unsupported-fragment|unsupported:reserved-identifier|different|reserved-identifier-not-uf|true|false|exact
    #|z3_arch_unsupported_define_fun_nonnullary|smt2/z3_arch_unsupported_define_fun_nonnullary.smt2|smt2/z3_arch_unsupported_define_fun_nonnullary.expected.out||0|parser-runner,file-shell,interactive-shell|1|unsupported-define-fun-nonnullary|explicit-unsupported|command|parser|unsupported-command|unsupported-fragment|unsupported:define-fun|different|phase-limited-define-fun|true|false|exact
    #|z3_arch_unsupported_parametric_sort|smt2/z3_arch_unsupported_parametric_sort.smt2|smt2/z3_arch_unsupported_parametric_sort.expected.out||0|parser-runner,file-shell,interactive-shell|1|unsupported-parametric-sort|explicit-unsupported|sort|cmd-context|unsupported-fragment|unsupported-fragment|unsupported:sort-arity|different|phase-limited-parametric-sorts|true|false|exact
    #|z3_arch_global_decls_default|smt2/z3_arch_global_decls_default.smt2|smt2/z3_arch_global_decls_default.expected.out||0|parser-runner,file-shell,interactive-shell|5|global-decls-default|supported-error|Bool|parser|undeclared-symbol|none|type:undeclared-symbol|same|none|false|false|exact
    #|z3_arch_global_decls_enabled|smt2/z3_arch_global_decls_enabled.smt2|smt2/z3_arch_global_decls_enabled.expected.out||0|parser-runner,file-shell,interactive-shell|7|global-decls-enabled|supported-success|Bool|none|sat-after-pop-global-decl|none|none|same|none|false|false|exact
    #|z3_arch_global_declarations_alias|smt2/z3_arch_global_declarations_alias.smt2|smt2/z3_arch_global_declarations_alias.expected.out||0|parser-runner,file-shell,interactive-shell|7|global-declarations-alias|supported-success|Bool|none|sat-after-pop-global-decl|none|none|same|none|false|false|exact
    #|z3_arch_global_decls_late_set|smt2/z3_arch_global_decls_late_set.smt2|smt2/z3_arch_global_decls_late_set.expected.out||0|parser-runner,file-shell,interactive-shell|5|global-decls-late-set|supported-error|Bool|cmd-context|late-option|none|solver:global-decls-active|different|z0-uses-stable-context-error|false|false|exact
    #|z3_arch_global_declarations_alias_late_set|smt2/z3_arch_global_declarations_alias_late_set.smt2|smt2/z3_arch_global_declarations_alias_late_set.expected.out||0|parser-runner,file-shell,interactive-shell|5|global-declarations-alias-late-set|supported-error|Bool|cmd-context|late-option|none|solver:global-decls-active|different|z0-uses-stable-context-error|false|false|exact
    #|z3_arch_global_decls_reset|smt2/z3_arch_global_decls_reset.smt2|smt2/z3_arch_global_decls_reset.expected.out||0|parser-runner,file-shell,interactive-shell|8|global-decls-reset|supported-success|Bool|none|reset-option-persistence|none|none|same|none|false|false|exact
    #|z3_arch_pop_underflow|smt2/z3_arch_pop_underflow.smt2|smt2/z3_arch_pop_underflow.expected.out||0|parser-runner,file-shell,interactive-shell|1|pop-underflow|supported-error|command|cmd-context|invalid-pop|none|solver:invalid-pop|different|z0-uses-stable-invalid-pop-diagnostic|false|false|exact
    #|z3_arch_pop_over_scope|smt2/z3_arch_pop_over_scope.smt2|smt2/z3_arch_pop_over_scope.expected.out||0|parser-runner,file-shell,interactive-shell|5|pop-over-scope|supported-error|command|cmd-context|invalid-pop|none|solver:invalid-pop|different|z0-uses-stable-invalid-pop-diagnostic|false|false|exact
    #|z3_arch_builtin_option_storage|smt2/z3_arch_builtin_option_storage.smt2|smt2/z3_arch_builtin_option_storage.expected.out||0|parser-runner,file-shell,interactive-shell|19|builtin-option-storage|supported-success|options|none|option-roundtrip|none|none|different|z0-stores-error-behavior-and-runner-uses-core-modes|false|false|exact
    #|z3_arch_builtin_options_reset|smt2/z3_arch_builtin_options_reset.smt2|smt2/z3_arch_builtin_options_reset.expected.out||0|parser-runner,file-shell,interactive-shell|23|builtin-options-reset|supported-success|options|none|reset-option-persistence|none|none|same|none|false|false|exact
    #|z3_arch_auto_config_option|smt2/z3_arch_auto_config_option.smt2|smt2/z3_arch_auto_config_option.expected.out||0|parser-runner,file-shell,interactive-shell|5|auto-config-option|supported-success|options|none|auto-config-roundtrip-reset|none|none|same|none|false|false|exact
    #|z3_arch_reproducible_resource_limit_option|smt2/z3_arch_reproducible_resource_limit_option.smt2|smt2/z3_arch_reproducible_resource_limit_option.expected.out||0|parser-runner,file-shell,interactive-shell|5|reproducible-resource-limit-option|supported-success|options|none|reproducible-resource-limit-roundtrip-reset|none|none|same|none|false|false|exact
    #|z3_arch_builtin_option_invalid_value|smt2/z3_arch_builtin_option_invalid_value.smt2|smt2/z3_arch_builtin_option_invalid_value.expected.out||1|parser-runner,file-shell,interactive-shell|4|builtin-option-invalid-value|supported-error|options|cmd-context|invalid-option-value|none|parse:option-invalid-verbosity|different|z0-uses-stable-option-validation-diagnostic|false|false|exact
    #|z3_arch_builtin_option_invalid_bool_enum|smt2/z3_arch_builtin_option_invalid_bool_enum.smt2|smt2/z3_arch_builtin_option_invalid_bool_enum.expected.out||1|parser-runner,file-shell,interactive-shell|7|builtin-option-invalid-bool-enum|supported-error|options|cmd-context|invalid-option-value|none|parse:option-invalid-bool-enum|different|z0-uses-stable-option-validation-diagnostic|false|false|exact
    #|z3_arch_regular_output_channel_stderr|smt2/z3_arch_regular_output_channel_stderr.smt2|smt2/z3_arch_regular_output_channel_stderr.expected.out|smt2/z3_arch_regular_output_channel_stderr.expected.err|0|file-shell,interactive-shell|3|regular-output-channel-stderr|supported-success|options|none|regular-output-channel-routing|none|none|same|none|false|false|exact
    #|z3_arch_diagnostic_output_channel_stderr|smt2/z3_arch_diagnostic_output_channel_stderr.smt2|smt2/z3_arch_diagnostic_output_channel_stderr.expected.out|smt2/z3_arch_diagnostic_output_channel_stderr.expected.err|1|file-shell,interactive-shell|4|diagnostic-output-channel-stderr|supported-error|options|runner|diagnostic-output-channel-routing|none|parse:push-count|same|none|false|false|exact
    #|z3_arch_unsupported_set_option|smt2/z3_arch_unsupported_set_option.smt2|smt2/z3_arch_unsupported_set_option.expected.out||0|parser-runner,file-shell,interactive-shell|1|unsupported-set-option|explicit-unsupported|options|cmd-context|unsupported-option|unsupported-fragment|unsupported:option|different|phase-limited-module-options|true|false|exact
    #|z3_arch_unsupported_get_option|smt2/z3_arch_unsupported_get_option.smt2|smt2/z3_arch_unsupported_get_option.expected.out||0|parser-runner,file-shell,interactive-shell|1|unsupported-get-option|explicit-unsupported|options|cmd-context|unsupported-option|unsupported-fragment|unsupported:option|different|phase-limited-module-options|true|false|exact
    #|z3_arch_set_info_print_success|smt2/z3_arch_set_info_print_success.smt2|smt2/z3_arch_set_info_print_success.expected.out||0|parser-runner,file-shell,interactive-shell|4|set-info-print-success|supported-success|info|none|metadata-print-success|none|none|same|none|false|false|exact
    #|z3_arch_unsupported_get_info|smt2/z3_arch_unsupported_get_info.smt2|smt2/z3_arch_unsupported_get_info.expected.out||0|parser-runner,file-shell,interactive-shell|1|unsupported-get-info|explicit-unsupported|info|cmd-context|unsupported-info-key|unsupported-fragment|unsupported:info|different|phase-limited-info-key|true|false|exact
    #|z3_arch_info_statistics_rlimit|smt2/z3_arch_info_statistics_rlimit.smt2|smt2/z3_arch_info_statistics_rlimit.expected.out||0|parser-runner,file-shell,interactive-shell|6|get-info-statistics-rlimit|supported-success|info|none|rlimit-statistics|none|none|different|z0-statistics-key-subset-exact|false|false|exact
    #|z3_arch_info_statistics_no_check|smt2/z3_arch_info_statistics_no_check.smt2|smt2/z3_arch_info_statistics_no_check.expected.out||0|parser-runner,file-shell,interactive-shell|4|get-info-statistics-no-check|supported-success|info|none|rlimit-statistics-no-check|none|none|different|z0-statistics-empty-no-check-exact|false|false|exact
    #|z3_arch_info_reason_unknown_default|smt2/z3_arch_info_reason_unknown_default.smt2|smt2/z3_arch_info_reason_unknown_default.expected.out||0|parser-runner,file-shell,interactive-shell|6|get-info-reason-unknown-default|supported-success|info|none|reason-unknown-default-stale|no-current-result|none|different|z0-reports-stale-after-context-mutation|false|false|exact
    #|z3_arch_info_reason_unknown_unsat|smt2/z3_arch_info_reason_unknown_unsat.smt2|smt2/z3_arch_info_reason_unknown_unsat.expected.out||0|parser-runner,file-shell,interactive-shell|5|get-info-reason-unknown-unsat|supported-success|info|none|reason-unknown-unsat-cleared|no-current-result|none|same|none|false|false|exact
    #|z3_arch_reset_clears_reason_unknown|smt2/z3_arch_reset_clears_reason_unknown.smt2|smt2/z3_arch_reset_clears_reason_unknown.expected.out||0|parser-runner,file-shell,interactive-shell|6|get-info-reason-unknown-reset|supported-success|info|none|reason-unknown-reset-cleared|no-current-result|none|same|none|false|false|exact
    #|z3_arch_custom_statistics_incomplete|smt2/z3_arch_custom_statistics_incomplete.smt2|smt2/z3_arch_custom_statistics_incomplete.expected.out||0|parser-runner|1|custom-factory-statistics|supported-success|custom-factory|solver|statistics-incomplete-missing-owner|incomplete-theory(stats)|statistics-missing-owner:backend.custom|different|z0-custom-factory-statistics|false|false|exact
    #|z3_arch_custom_statistics_schema|smt2/z3_arch_custom_statistics_schema.smt2|smt2/z3_arch_custom_statistics_schema.expected.out||0|parser-runner|1|custom-factory-statistics|supported-success|custom-factory|solver|statistics-schema|incomplete-theory(stats)|statistics-missing-owner:backend.custom|different|z0-custom-factory-statistics-schema|false|false|statistics-schema
    #|z3_arch_custom_unknown_with_model|smt2/z3_arch_custom_unknown_with_model.smt2|smt2/z3_arch_custom_unknown_with_model.expected.out||0|parser-runner|7|custom-factory-unknown-with-model|supported-unknown|custom-factory|solver|unknown-with-model|maybe|none|different|z0-custom-factory-with-model|false|true|exact
    #|z3_arch_custom_unknown_no_model|smt2/z3_arch_custom_unknown_no_model.smt2|smt2/z3_arch_custom_unknown_no_model.expected.out||0|parser-runner|6|custom-factory-unknown-no-model|supported-unknown|custom-factory|solver|unknown-no-model|maybe|error:model-eval-unavailable|different|z0-custom-factory-no-model|false|true|exact
    #|z3_arch_custom_timeout_reason|smt2/z3_arch_custom_timeout_reason.smt2|smt2/z3_arch_custom_timeout_reason.expected.out||0|parser-runner|2|custom-factory-reason|supported-unknown|custom-factory|solver|unknown-timeout|timeout|none|different|z0-custom-factory-reason|false|true|exact
    #|z3_arch_custom_memout_reason|smt2/z3_arch_custom_memout_reason.smt2|smt2/z3_arch_custom_memout_reason.expected.out||0|parser-runner|2|custom-factory-reason|supported-unknown|custom-factory|solver|unknown-memout|memout|none|different|z0-custom-factory-reason|false|true|exact
    #|z3_arch_custom_max_conflicts_reason|smt2/z3_arch_custom_max_conflicts_reason.smt2|smt2/z3_arch_custom_max_conflicts_reason.expected.out||0|parser-runner|2|custom-factory-reason|supported-unknown|custom-factory|solver|unknown-max-conflicts|max-conflicts|none|different|z0-custom-factory-reason|false|true|exact
    #|z3_arch_custom_resource_limit_reason|smt2/z3_arch_custom_resource_limit_reason.smt2|smt2/z3_arch_custom_resource_limit_reason.expected.out||0|parser-runner|2|custom-factory-reason|supported-unknown|custom-factory|solver|unknown-resource-limit|resource-limit-exceeded|none|different|z0-custom-factory-reason|false|true|exact
    #|z3_arch_custom_canceled_reason|smt2/z3_arch_custom_canceled_reason.smt2|smt2/z3_arch_custom_canceled_reason.expected.out||0|parser-runner|2|custom-factory-reason|supported-unknown|custom-factory|solver|unknown-canceled|canceled(api)|none|different|z0-custom-factory-reason|false|true|exact
    #|z3_arch_custom_unsupported_fragment_reason|smt2/z3_arch_custom_unsupported_fragment_reason.smt2|smt2/z3_arch_custom_unsupported_fragment_reason.expected.out||0|parser-runner|2|custom-factory-reason|supported-unknown|custom-factory|solver|unknown-unsupported-fragment|unsupported-fragment(array)|none|different|z0-custom-factory-reason|true|true|exact
    #|z3_arch_custom_invalid_core_reason|smt2/z3_arch_custom_invalid_core_reason.smt2|smt2/z3_arch_custom_invalid_core_reason.expected.out||0|parser-runner|2|custom-factory-reason|supported-unknown|custom-factory|solver|unknown-invalid-core|invalid-core|none|different|z0-custom-factory-reason|false|true|exact
    #|z3_arch_custom_invalid_proof_reason|smt2/z3_arch_custom_invalid_proof_reason.smt2|smt2/z3_arch_custom_invalid_proof_reason.expected.out||0|parser-runner|2|custom-factory-reason|supported-unknown|custom-factory|solver|unknown-invalid-proof|invalid-proof|none|different|z0-custom-factory-reason|false|true|exact
    #|z3_arch_custom_invalid_model_reason|smt2/z3_arch_custom_invalid_model_reason.smt2|smt2/z3_arch_custom_invalid_model_reason.expected.out||0|parser-runner|2|custom-factory-reason|supported-unknown|custom-factory|solver|unknown-invalid-model|invalid-model|none|different|z0-custom-factory-reason|false|true|exact
    #|z3_arch_custom_incomplete_theory_reason|smt2/z3_arch_custom_incomplete_theory_reason.smt2|smt2/z3_arch_custom_incomplete_theory_reason.expected.out||0|parser-runner|2|custom-factory-reason|supported-unknown|custom-factory|solver|unknown-incomplete-theory|incomplete-theory(fake)|none|different|z0-custom-factory-reason|false|true|exact
    #|z3_arch_custom_incomplete_quantifiers_reason|smt2/z3_arch_custom_incomplete_quantifiers_reason.smt2|smt2/z3_arch_custom_incomplete_quantifiers_reason.expected.out||0|parser-runner|2|custom-factory-reason|supported-unknown|custom-factory|solver|unknown-incomplete-quantifiers|incomplete-quantifiers|none|different|z0-custom-factory-reason|false|true|exact
    #|z3_arch_custom_incomplete_lambdas_reason|smt2/z3_arch_custom_incomplete_lambdas_reason.smt2|smt2/z3_arch_custom_incomplete_lambdas_reason.expected.out||0|parser-runner|2|custom-factory-reason|supported-unknown|custom-factory|solver|unknown-incomplete-lambdas|incomplete-lambdas|none|different|z0-custom-factory-reason|false|true|exact
    #|z3_arch_produce_flags_disabled|smt2/z3_arch_produce_flags_disabled.smt2|smt2/z3_arch_produce_flags_disabled.expected.out||0|parser-runner,file-shell,interactive-shell|9|produce-flags-disabled|supported-success|options|none|disabled-query|none|none|different|z0-emits-local-disabled-query-text|false|false|exact
    #|z3_arch_produce_models_late_enable|smt2/z3_arch_produce_models_late_enable.smt2|smt2/z3_arch_produce_models_late_enable.expected.out||0|parser-runner,file-shell,interactive-shell|5|produce-models-late-enable|supported-success|options|none|late-dynamic-option|none|none|same|none|false|false|exact
    #|z3_arch_produce_proofs_late_set|smt2/z3_arch_produce_proofs_late_set.smt2|smt2/z3_arch_produce_proofs_late_set.expected.out||0|parser-runner,file-shell,interactive-shell|3|produce-proofs-late-set|supported-error|options|cmd-context|late-option|none|solver:late-option-produce-proofs|different|z0-uses-stable-late-option-diagnostic|false|false|exact
    #|z3_arch_produce_unsat_cores_late_set|smt2/z3_arch_produce_unsat_cores_late_set.smt2|smt2/z3_arch_produce_unsat_cores_late_set.expected.out||0|parser-runner,file-shell,interactive-shell|3|produce-unsat-cores-late-set|supported-error|options|cmd-context|late-option|none|solver:late-option-produce-unsat-cores|different|z0-uses-stable-late-option-diagnostic|false|false|exact
    #|z3_arch_produce_unsat_assumptions_late_set|smt2/z3_arch_produce_unsat_assumptions_late_set.smt2|smt2/z3_arch_produce_unsat_assumptions_late_set.expected.out||0|parser-runner,file-shell,interactive-shell|3|produce-unsat-assumptions-late-set|supported-error|options|cmd-context|late-option|none|solver:late-option-produce-unsat-assumptions|different|z0-uses-stable-late-option-diagnostic|false|false|exact
    #|z3_arch_reset_assertions_reopens_produce_flags|smt2/z3_arch_reset_assertions_reopens_produce_flags.smt2|smt2/z3_arch_reset_assertions_reopens_produce_flags.expected.out||0|parser-runner,file-shell,interactive-shell|12|reset-assertions-produce-flags|supported-success|options|none|reset-assertions-option-reopen|none|none|different|z0-uses-proof-skeleton-text|false|false|exact
    #|z3_arch_reset_assertions_scope_replay|smt2/z3_arch_reset_assertions_scope_replay.smt2|smt2/z3_arch_reset_assertions_scope_replay.expected.out||0|parser-runner,file-shell,interactive-shell|8|reset-assertions-scope-replay|supported-success|Bool|none|reset-assertions-scope-depth-replay|none|none|same|none|false|false|exact
    #|z3_arch_reset_reopens_produce_flags|smt2/z3_arch_reset_reopens_produce_flags.smt2|smt2/z3_arch_reset_reopens_produce_flags.expected.out||0|parser-runner,file-shell,interactive-shell|13|reset-produce-flags|supported-success|options|none|reset-option-reopen|none|none|different|z0-uses-proof-skeleton-text|false|false|exact
    #|z3_arch_reset_clears_macro_env|smt2/z3_arch_reset_clears_macro_env.smt2|smt2/z3_arch_reset_clears_macro_env.expected.out||0|parser-runner,file-shell,interactive-shell|8|reset-clears-macro-env|supported-error|Bool|parser|reset-clears-declarations-macros|none|type:undeclared-symbol|same|none|false|false|exact
    #|z3_arch_set_logic_ordering|smt2/z3_arch_set_logic_ordering.smt2|smt2/z3_arch_set_logic_ordering.expected.out||0|parser-runner,file-shell,interactive-shell|11|set-logic-ordering|supported-error|setup|cmd-context|late-logic-after-assertion|none|solver:set-logic-after-assertions|same|none|false|false|exact
    #|z3_arch_set_logic_duplicate|smt2/z3_arch_set_logic_duplicate.smt2|smt2/z3_arch_set_logic_duplicate.expected.out||0|parser-runner,file-shell,interactive-shell|2|set-logic-duplicate|supported-error|setup|cmd-context|duplicate-logic|none|solver:logic-already-set|same|none|false|false|exact
    #|z3_arch_unsupported_logic_recovery|smt2/z3_arch_unsupported_logic_recovery.smt2|smt2/z3_arch_unsupported_logic_recovery.expected.out||0|parser-runner,file-shell,interactive-shell|5|unsupported-logic-recovery|explicit-unsupported|setup|cmd-context|unsupported-logic-state-unchanged|unsupported-logic|unsupported:logic|different|phase-limited-logic|true|false|exact
    #|z3_arch_set_logic_option_ordering|smt2/z3_arch_set_logic_option_ordering.smt2|smt2/z3_arch_set_logic_option_ordering.expected.out||0|parser-runner,file-shell,interactive-shell|11|set-logic-option-ordering|supported-success|options|none|setup-preassert-dynamic-options|none|none|different|z0-uses-print-success-for-command-side-effects|false|false|exact
    #|z3_arch_exit_stops_runner|smt2/z3_arch_exit_stops_runner.smt2|smt2/z3_arch_exit_stops_runner.expected.out||0|parser-runner,file-shell,interactive-shell|3|exit-stops-runner|supported-success|command|none|exit-stops-runner|none|none|same|none|false|false|exact
    #|z3_arch_error_recovery_unsupported_command|smt2/z3_arch_error_recovery_unsupported_command.smt2|smt2/z3_arch_error_recovery_unsupported_command.expected.out||0|parser-runner,file-shell,interactive-shell|3|error-recovery-unsupported-command|supported-error|command|parser|unsupported-command|unsupported-fragment|unsupported:unsupported-command|different|z0-prints-unsupported-diagnostic-in-regular-transcript|true|false|exact
    #|z3_arch_error_recovery_parse_continued|smt2/z3_arch_error_recovery_parse_continued.smt2|smt2/z3_arch_error_recovery_parse_continued.expected.out||1|parser-runner,file-shell,interactive-shell|3|error-recovery-parse-continued|supported-error|command|parser|parse-error-continued|none|parse:push-count|different|z0-shell-reports-command-parse-error-exit|false|false|exact
    #|z3_arch_error_recovery_immediate_exit|smt2/z3_arch_error_recovery_immediate_exit.smt2|smt2/z3_arch_error_recovery_immediate_exit.expected.out||1|parser-runner,file-shell,interactive-shell|4|error-recovery-immediate-exit|supported-error|options|runner|parse-error-immediate-exit|none|parse:push-count|same|none|false|false|exact
    #|
  )
}

///|
fn parse_bool_manifest_field(value : String) -> Bool {
  match value {
    "true" => true
    "false" => false
    _ => abort("invalid manifest bool field: \{value}")
  }
}

///|
fn parse_manifest_line(line : String) -> Z3ArchManifestEntry {
  let columns = line.split("|").map(part => part.trim().to_owned()).to_array()
  if columns.length() != 19 {
    abort("expected 19 manifest columns, got \{columns.length()}: \{line}")
  }
  {
    id: columns[0],
    input_file: columns[1],
    expected_stdout: columns[2],
    expected_stderr: columns[3],
    expected_exit_code: columns[4],
    runner_modes: columns[5],
    command_count: columns[6],
    command_kind: columns[7],
    support_status: columns[8],
    syntax_family: columns[9],
    reject_stage: columns[10],
    status_category: columns[11],
    reason_unknown: columns[12],
    diagnostic: columns[13],
    z3_expected: columns[14],
    z3_diff_reason: columns[15],
    allow_unsupported: parse_bool_manifest_field(columns[16]),
    allow_unknown: parse_bool_manifest_field(columns[17]),
    normalization: columns[18],
  }
}

///|
fn parse_z3_arch_manifest(text : String) -> Array[Z3ArchManifestEntry] {
  let entries : Array[Z3ArchManifestEntry] = []
  for raw_line in text.split("\n") {
    let line = raw_line.trim().to_owned()
    if !line.is_empty() && !line.contains("id|input_file") {
      entries.push(parse_manifest_line(line))
    }
  }
  entries
}

///|
fn z3_arch_read_file(path : String) -> String {
  @fs.read_file_to_string(path) catch {
    @fs.IOError(message) => abort("failed to read \{path}: \{message}")
  }
}

///|
fn z3_arch_disk_manifest_text() -> String {
  z3_arch_read_file("smt2/z3_arch_manifest.txt")
}

///|
fn z3_arch_trim_final_newlines(text : String) -> String {
  text.trim_end(chars="\n").to_owned()
}

///|
fn z3_arch_normalize_transcript(text : String) -> String {
  z3_arch_trim_final_newlines(text) + "\n"
}

///|
fn z3_arch_normalization_supported(normalization : String) -> Bool {
  normalization == "exact" || normalization == "statistics-schema"
}

///|
fn z3_arch_schema_payload(line : String, prefix : String) -> String? {
  if line.has_prefix(prefix) {
    let parts = line.split(prefix).map(part => part.to_owned()).to_array()
    if parts.length() >= 2 {
      Some(parts[1])
    } else {
      Some("")
    }
  } else {
    None
  }
}

///|
fn z3_arch_assert_contains(
  output : String,
  token : String,
  id : String,
) -> Unit raise {
  if !output.contains(token) {
    fail("statistics schema fixture \{id} missing token: \{token}")
  }
}

///|
fn z3_arch_assert_statistics_schema(
  output : String,
  schema : String,
  id : String,
) -> Unit raise {
  let normalized = z3_arch_normalize_transcript(output)
  if !normalized.has_prefix("(:all-statistics") {
    fail("statistics schema fixture \{id} did not output :all-statistics")
  }
  for raw_line in schema.split("\n") {
    let line = raw_line.trim().to_owned()
    if !line.is_empty() {
      match z3_arch_schema_payload(line, "prefix:") {
        Some(prefix) =>
          if !normalized.has_prefix(prefix) {
            fail("statistics schema fixture \{id} missing prefix: \{prefix}")
          }
        None =>
          match z3_arch_schema_payload(line, "contains:") {
            Some(token) => z3_arch_assert_contains(normalized, token, id)
            None =>
              match z3_arch_schema_payload(line, "key:") {
                Some(key) => z3_arch_assert_contains(normalized, key, id)
                None =>
                  match z3_arch_schema_payload(line, "reason:") {
                    Some(reason) =>
                      z3_arch_assert_contains(normalized, reason, id)
                    None =>
                      fail(
                        "unknown statistics schema directive for \{id}: \{line}",
                      )
                  }
              }
          }
      }
    }
  }
}

///|
fn z3_arch_compare_transcript(
  entry : Z3ArchManifestEntry,
  output : String,
  expected : String,
) -> Unit raise {
  match entry.normalization {
    "exact" =>
      inspect(
        z3_arch_normalize_transcript(output),
        content=z3_arch_normalize_transcript(expected),
      )
    "statistics-schema" =>
      z3_arch_assert_statistics_schema(output, expected, entry.id)
    _ =>
      fail("unsupported normalization for \{entry.id}: \{entry.normalization}")
  }
}

///|
fn z3_arch_fixture_ids() -> Array[String] {
  [
    "z3_arch_bool_incremental", "z3_arch_assumptions_core", "z3_arch_define_fun_bool",
    "z3_arch_model_eval", "z3_arch_eval_completion", "z3_arch_eval_availability",
    "z3_arch_let_bool", "z3_arch_let_euf", "z3_arch_model_query_availability", "z3_arch_model_query_stale",
    "z3_arch_model_repeated_scoped", "z3_arch_model_euf_constants", "z3_arch_model_partial_unary_uf",
    "z3_arch_get_value_partial_uf_completion", "z3_arch_proof_modes", "z3_arch_proof_availability",
    "z3_arch_unknown_unsupported", "z3_arch_unsat_query_availability", "z3_arch_global_decls_default",
    "z3_arch_unsupported_array_sort", "z3_arch_unsupported_array_select_store", "z3_arch_unsupported_bv_sort",
    "z3_arch_unsupported_bv_literal", "z3_arch_unsupported_bv_indexed_op", "z3_arch_unsupported_datatype_decl",
    "z3_arch_unsupported_datatype_constructor", "z3_arch_unsupported_datatype_match",
    "z3_arch_unsupported_string_sort", "z3_arch_unsupported_string_literal", "z3_arch_unsupported_seq_op",
    "z3_arch_unsupported_exists", "z3_arch_unsupported_reserved_identifier", "z3_arch_unsupported_define_fun_nonnullary",
    "z3_arch_unsupported_parametric_sort", "z3_arch_global_decls_enabled", "z3_arch_global_decls_late_set",
    "z3_arch_global_declarations_alias_late_set", "z3_arch_global_decls_reset", "z3_arch_global_declarations_alias",
    "z3_arch_pop_underflow", "z3_arch_pop_over_scope", "z3_arch_builtin_option_storage",
    "z3_arch_builtin_options_reset", "z3_arch_auto_config_option", "z3_arch_builtin_option_invalid_value",
    "z3_arch_reproducible_resource_limit_option", "z3_arch_builtin_option_invalid_bool_enum",
    "z3_arch_unsupported_set_option", "z3_arch_unsupported_get_option", "z3_arch_set_info_print_success",
    "z3_arch_unsupported_get_info", "z3_arch_info_statistics_rlimit", "z3_arch_info_statistics_no_check",
    "z3_arch_info_reason_unknown_default", "z3_arch_info_reason_unknown_unsat", "z3_arch_reset_clears_reason_unknown",
    "z3_arch_custom_statistics_incomplete", "z3_arch_custom_statistics_schema", "z3_arch_custom_unknown_with_model",
    "z3_arch_custom_unknown_no_model", "z3_arch_custom_timeout_reason", "z3_arch_custom_memout_reason",
    "z3_arch_custom_max_conflicts_reason", "z3_arch_custom_resource_limit_reason",
    "z3_arch_custom_canceled_reason", "z3_arch_custom_unsupported_fragment_reason",
    "z3_arch_custom_invalid_core_reason", "z3_arch_custom_invalid_proof_reason",
    "z3_arch_custom_invalid_model_reason", "z3_arch_custom_incomplete_theory_reason",
    "z3_arch_custom_incomplete_quantifiers_reason", "z3_arch_custom_incomplete_lambdas_reason",
    "z3_arch_produce_flags_disabled", "z3_arch_produce_models_late_enable", "z3_arch_produce_proofs_late_set",
    "z3_arch_produce_unsat_cores_late_set", "z3_arch_produce_unsat_assumptions_late_set",
    "z3_arch_reset_assertions_reopens_produce_flags", "z3_arch_reset_assertions_scope_replay",
    "z3_arch_reset_reopens_produce_flags", "z3_arch_reset_clears_macro_env", "z3_arch_set_logic_ordering",
    "z3_arch_set_logic_duplicate", "z3_arch_unsupported_logic_recovery", "z3_arch_set_logic_option_ordering",
    "z3_arch_exit_stops_runner", "z3_arch_error_recovery_unsupported_command", "z3_arch_error_recovery_parse_continued",
    "z3_arch_error_recovery_immediate_exit",
  ]
}

///|
fn z3_arch_fixture_input(id : String) -> String {
  match id {
    "z3_arch_bool_incremental" =>
      "(set-logic QF_UF)\n(declare-const p Bool)\n(push)\n(assert p)\n(assert (not p))\n(check-sat)\n(pop)\n(check-sat)"
    "z3_arch_assumptions_core" =>
      "(set-option :produce-unsat-assumptions true)\n(declare-const p Bool)\n(assert p)\n(check-sat-assuming ((not p)))\n(get-unsat-assumptions)"
    "z3_arch_let_bool" =>
      "(set-logic QF_UF)\n(declare-const p Bool)\n(assert (let ((x p)) (and x (not x))))\n(check-sat)"
    "z3_arch_let_euf" =>
      "(set-logic QF_UF)\n(declare-sort U 0)\n(declare-const a U)\n(declare-const b U)\n(assert (= a b))\n(assert (let ((x a) (y b)) (distinct x y)))\n(check-sat)"
    "z3_arch_define_fun_bool" =>
      "(declare-const p Bool)\n(define-fun m () Bool p)\n(assert (not m))\n(assert p)\n(check-sat)"
    "z3_arch_model_eval" =>
      "(set-option :produce-models true)\n(declare-const p Bool)\n(assert p)\n(check-sat)\n(get-value (p (not p)))\n(eval p)\n(eval p :completion true)"
    "z3_arch_eval_completion" =>
      "(set-option :produce-models true)\n(declare-sort U 0)\n(declare-const a U)\n(check-sat)\n(eval a)\n(eval a :completion true)"
    "z3_arch_eval_availability" =>
      "(declare-const p Bool)\n(eval p)\n(set-option :produce-models true)\n(eval p)\n(assert p)\n(check-sat)\n(eval p)"
    "z3_arch_model_query_availability" =>
      "(set-option :produce-models true)\n(declare-sort U 0)\n(declare-const a U)\n(get-model)\n(get-value (a))\n(check-sat)\n(eval a)"
    "z3_arch_model_query_stale" =>
      "(set-option :produce-models true)\n(declare-const p Bool)\n(check-sat)\n(push)\n(get-model)\n(check-sat)\n(pop)\n(get-value (p))\n(check-sat)\n(assert p)\n(eval p)"
    "z3_arch_model_repeated_scoped" =>
      "(set-option :produce-models true)\n(declare-const p Bool)\n(assert p)\n(check-sat)\n(get-model)\n(get-model)\n(push)\n(assert (not p))\n(check-sat)\n(pop)\n(check-sat)\n(get-model)"
    "z3_arch_model_euf_constants" =>
      "(set-logic QF_UF)\n(set-option :produce-models true)\n(declare-sort U 0)\n(declare-const a U)\n(declare-const b U)\n(assert (distinct a b))\n(check-sat)\n(get-model)"
    "z3_arch_model_partial_unary_uf" =>
      "(set-logic QF_UF)\n(set-option :produce-models true)\n(declare-sort U 0)\n(declare-const a U)\n(declare-const b U)\n(declare-fun f (U) U)\n(assert (= (f a) b))\n(check-sat)\n(get-model)"
    "z3_arch_get_value_partial_uf_completion" =>
      "(set-logic QF_UF)\n(set-option :produce-models true)\n(declare-sort U 0)\n(declare-const a U)\n(declare-const b U)\n(declare-const c U)\n(declare-fun f (U) U)\n(assert (= (f a) b))\n(check-sat)\n(get-value ((f c)))"
    "z3_arch_proof_modes" =>
      "(declare-const p Bool)\n(assert p)\n(assert (not p))\n(check-sat)\n(get-proof)\n(reset)\n(set-option :produce-proofs true)\n(declare-const p Bool)\n(assert p)\n(assert (not p))\n(check-sat)\n(get-proof)"
    "z3_arch_proof_availability" =>
      "(set-option :produce-proofs true)\n(get-proof)\n(declare-const p Bool)\n(assert p)\n(check-sat)\n(get-proof)\n(assert (not p))\n(get-proof)"
    "z3_arch_unsat_query_availability" =>
      "(set-option :produce-unsat-cores true)\n(set-option :produce-unsat-assumptions true)\n(get-unsat-core)\n(get-unsat-assumptions)\n(declare-const p Bool)\n(assert p)\n(check-sat)\n(get-unsat-core)\n(get-unsat-assumptions)\n(assert (not p))\n(get-unsat-core)\n(get-unsat-assumptions)"
    "z3_arch_unknown_unsupported" =>
      "(set-logic QF_UF)\n(declare-sort U 0)\n(declare-const a U)\n(assert (forall ((x U)) (= x a)))\n(check-sat)"
    "z3_arch_unsupported_array_sort" => "(declare-const a (Array Int Int))"
    "z3_arch_unsupported_array_select_store" => "(assert (select true true))"
    "z3_arch_unsupported_bv_sort" => "(declare-const x (_ BitVec 8))"
    "z3_arch_unsupported_bv_literal" => "(assert #x0f)"
    "z3_arch_unsupported_bv_indexed_op" => "(assert ((_ extract 3 0) #x0f))"
    "z3_arch_unsupported_datatype_decl" =>
      "(declare-datatypes ((List 0)) (((nil))))"
    "z3_arch_unsupported_datatype_constructor" => "(assert (as nil List))"
    "z3_arch_unsupported_datatype_match" =>
      "(assert (match true ((true true))))"
    "z3_arch_unsupported_string_sort" => "(declare-const s String)"
    "z3_arch_unsupported_string_literal" => "(assert \"abc\")"
    "z3_arch_unsupported_seq_op" => "(assert (str.++ \"a\" \"b\"))"
    "z3_arch_unsupported_exists" =>
      "(declare-sort U 0)\n(declare-const a U)\n(assert (exists ((x U)) (= x a)))\n(check-sat)"
    "z3_arch_unsupported_reserved_identifier" => "(assert (par true))"
    "z3_arch_unsupported_define_fun_nonnullary" =>
      "(define-fun f ((x Bool)) Bool true)"
    "z3_arch_unsupported_parametric_sort" => "(declare-sort Vec 1)"
    "z3_arch_global_decls_default" =>
      "(push)\n(declare-const p Bool)\n(pop)\n(assert p)\n(check-sat)"
    "z3_arch_global_decls_enabled" =>
      "(set-option :global-decls true)\n(push)\n(declare-const p Bool)\n(pop)\n(assert p)\n(check-sat)\n(get-option :global-decls)"
    "z3_arch_global_declarations_alias" =>
      "(set-option :global-declarations true)\n(push)\n(declare-const p Bool)\n(pop)\n(assert p)\n(check-sat)\n(get-option :global-declarations)"
    "z3_arch_global_decls_late_set" =>
      "(push)\n(set-option :global-decls true)\n(declare-const p Bool)\n(pop)\n(assert p)"
    "z3_arch_global_declarations_alias_late_set" =>
      "(push)\n(set-option :global-declarations true)\n(declare-const p Bool)\n(pop)\n(assert p)"
    "z3_arch_global_decls_reset" =>
      "(set-option :global-decls true)\n(reset)\n(get-option :global-decls)\n(push)\n(declare-const p Bool)\n(pop)\n(assert p)\n(check-sat)"
    "z3_arch_pop_underflow" => "(pop)"
    "z3_arch_pop_over_scope" =>
      "(push)\n(declare-const p Bool)\n(pop 2)\n(assert p)\n(check-sat)"
    "z3_arch_builtin_option_storage" =>
      "(get-option :print-warning)\n(get-option :verbosity)\n(get-option :random-seed)\n(get-option :numeral-as-real)\n(get-option :int-real-coercions)\n(get-option :error-behavior)\n(set-option :print-warning false)\n(set-option :verbosity 3)\n(set-option :random-seed 11)\n(set-option :numeral-as-real true)\n(set-option :int-real-coercions false)\n(set-option :error-behavior immediate-exit)\n(get-option :print-warning)\n(get-option :verbosity)\n(get-option :random-seed)\n(get-option :numeral-as-real)\n(get-option :int-real-coercions)\n(get-option :error-behavior)\n(get-info :error-behavior)"
    "z3_arch_builtin_options_reset" =>
      "(set-option :print-success true)\n(set-option :produce-models true)\n(set-option :produce-proofs true)\n(set-option :produce-unsat-cores true)\n(set-option :produce-unsat-assumptions true)\n(set-option :regular-output-channel \"stdout\")\n(set-option :diagnostic-output-channel \"stderr\")\n(set-option :verbosity 3)\n(set-option :random-seed 11)\n(set-option :print-warning false)\n(set-option :error-behavior immediate-exit)\n(reset)\n(get-option :print-success)\n(get-option :produce-models)\n(get-option :produce-proofs)\n(get-option :produce-unsat-cores)\n(get-option :produce-unsat-assumptions)\n(get-option :regular-output-channel)\n(get-option :diagnostic-output-channel)\n(get-option :verbosity)\n(get-option :random-seed)\n(get-option :print-warning)\n(get-option :error-behavior)"
    "z3_arch_auto_config_option" =>
      "(get-option :auto-config)\n(set-option :auto-config true)\n(get-option :auto-config)\n(reset)\n(get-option :auto-config)"
    "z3_arch_reproducible_resource_limit_option" =>
      "(get-option :reproducible-resource-limit)\n(set-option :reproducible-resource-limit 7)\n(get-option :reproducible-resource-limit)\n(reset)\n(get-option :reproducible-resource-limit)"
    "z3_arch_builtin_option_invalid_value" =>
      "(get-option :verbosity)\n(set-option :verbosity -1)\n(get-option :verbosity)\n(echo \"after\")"
    "z3_arch_builtin_option_invalid_bool_enum" =>
      "(get-option :print-warning)\n(set-option :print-warning maybe)\n(get-option :print-warning)\n(get-option :error-behavior)\n(set-option :error-behavior stop)\n(get-option :error-behavior)\n(echo \"after\")"
    "z3_arch_unsupported_set_option" => "(set-option :smt.relevancy 2)"
    "z3_arch_unsupported_get_option" => "(get-option :smt.relevancy)"
    "z3_arch_set_info_print_success" =>
      "(set-info :source \"z0\")\n(set-option :print-success true)\n(set-info :status unknown)\n(get-info :error-behavior)"
    "z3_arch_unsupported_get_info" => "(get-info :name)"
    "z3_arch_info_statistics_rlimit" =>
      "(set-option :reproducible-resource-limit 8)\n(get-info :rlimit)\n(declare-const p Bool)\n(check-sat)\n(get-info :all-statistics)\n(get-info :rlimit)"
    "z3_arch_info_statistics_no_check" =>
      "(set-option :reproducible-resource-limit 3)\n(get-info :all-statistics)\n(get-info :rlimit)\n(get-info :rlimit)"
    "z3_arch_info_reason_unknown_default" =>
      "(get-info :reason-unknown)\n(check-sat)\n(get-info :reason-unknown)\n(declare-const p Bool)\n(assert p)\n(get-info :reason-unknown)"
    "z3_arch_info_reason_unknown_unsat" =>
      "(declare-const p Bool)\n(assert p)\n(assert (not p))\n(check-sat)\n(get-info :reason-unknown)"
    "z3_arch_reset_clears_reason_unknown" =>
      "(check-sat)\n(reset-assertions)\n(get-info :reason-unknown)\n(check-sat)\n(reset)\n(get-info :reason-unknown)"
    "z3_arch_custom_statistics_incomplete" => "(get-info :all-statistics)"
    "z3_arch_custom_statistics_schema" => "(get-info :all-statistics)"
    "z3_arch_custom_unknown_with_model" =>
      "(set-option :produce-models true)\n(declare-const p Bool)\n(check-sat)\n(get-model)\n(get-value (p))\n(eval p)\n(get-info :reason-unknown)"
    "z3_arch_custom_unknown_no_model" =>
      "(set-option :produce-models true)\n(declare-const p Bool)\n(check-sat)\n(get-model)\n(eval p)\n(get-info :reason-unknown)"
    "z3_arch_custom_timeout_reason" => "(check-sat)\n(get-info :reason-unknown)"
    "z3_arch_custom_memout_reason" => "(check-sat)\n(get-info :reason-unknown)"
    "z3_arch_custom_max_conflicts_reason" =>
      "(check-sat)\n(get-info :reason-unknown)"
    "z3_arch_custom_resource_limit_reason" =>
      "(check-sat)\n(get-info :reason-unknown)"
    "z3_arch_custom_canceled_reason" =>
      "(check-sat)\n(get-info :reason-unknown)"
    "z3_arch_custom_unsupported_fragment_reason" =>
      "(check-sat)\n(get-info :reason-unknown)"
    "z3_arch_custom_invalid_core_reason" =>
      "(check-sat)\n(get-info :reason-unknown)"
    "z3_arch_custom_invalid_proof_reason" =>
      "(check-sat)\n(get-info :reason-unknown)"
    "z3_arch_custom_invalid_model_reason" =>
      "(check-sat)\n(get-info :reason-unknown)"
    "z3_arch_custom_incomplete_theory_reason" =>
      "(check-sat)\n(get-info :reason-unknown)"
    "z3_arch_custom_incomplete_quantifiers_reason" =>
      "(check-sat)\n(get-info :reason-unknown)"
    "z3_arch_custom_incomplete_lambdas_reason" =>
      "(check-sat)\n(get-info :reason-unknown)"
    "z3_arch_produce_flags_disabled" =>
      "(declare-const p Bool)\n(assert p)\n(assert (not p))\n(check-sat)\n(get-model)\n(get-proof)\n(get-unsat-core)\n(check-sat-assuming (p))\n(get-unsat-assumptions)"
    "z3_arch_produce_models_late_enable" =>
      "(declare-const p Bool)\n(assert p)\n(set-option :produce-models true)\n(check-sat)\n(get-model)"
    "z3_arch_produce_proofs_late_set" =>
      "(declare-const p Bool)\n(assert p)\n(set-option :produce-proofs true)"
    "z3_arch_produce_unsat_cores_late_set" =>
      "(declare-const p Bool)\n(assert p)\n(set-option :produce-unsat-cores true)"
    "z3_arch_produce_unsat_assumptions_late_set" =>
      "(declare-const p Bool)\n(assert p)\n(set-option :produce-unsat-assumptions true)"
    "z3_arch_reset_assertions_reopens_produce_flags" =>
      "(declare-const p Bool)\n(assert p)\n(reset-assertions)\n(set-option :produce-proofs true)\n(set-option :produce-unsat-cores true)\n(set-option :produce-unsat-assumptions true)\n(assert (! p :named core-p))\n(assert (not p))\n(check-sat)\n(get-proof)\n(get-unsat-core)\n(get-unsat-assumptions)"
    "z3_arch_reset_assertions_scope_replay" =>
      "(push)\n(declare-const p Bool)\n(assert p)\n(reset-assertions)\n(assert (not p))\n(check-sat)\n(pop)\n(check-sat)"
    "z3_arch_reset_reopens_produce_flags" =>
      "(declare-const p Bool)\n(assert p)\n(reset)\n(set-option :produce-proofs true)\n(set-option :produce-unsat-cores true)\n(set-option :produce-unsat-assumptions true)\n(declare-const p Bool)\n(assert (! p :named core-p))\n(assert (not p))\n(check-sat)\n(get-proof)\n(get-unsat-core)\n(get-unsat-assumptions)"
    "z3_arch_reset_clears_macro_env" =>
      "(set-logic QF_UF)\n(declare-const p Bool)\n(define-fun m () Bool p)\n(assert m)\n(check-sat)\n(reset)\n(set-logic QF_UF)\n(assert m)"
    "z3_arch_set_logic_ordering" =>
      "(declare-const p Bool)\n(set-logic QF_UF)\n(reset)\n(push)\n(set-logic QF_UF)\n(pop)\n(reset)\n(declare-const p Bool)\n(assert p)\n(set-logic QF_UF)\n(check-sat)"
    "z3_arch_set_logic_duplicate" => "(set-logic QF_UF)\n(set-logic QF_UF)"
    "z3_arch_unsupported_logic_recovery" =>
      "(set-logic QF_BOOL)\n(set-logic QF_UF)\n(declare-const p Bool)\n(assert p)\n(check-sat)"
    "z3_arch_set_logic_option_ordering" =>
      "(set-option :print-success true)\n(set-logic QF_UF)\n(set-option :global-decls true)\n(set-option :produce-proofs true)\n(push)\n(declare-const p Bool)\n(pop)\n(assert p)\n(set-option :produce-models true)\n(check-sat)\n(get-model)"
    "z3_arch_exit_stops_runner" => "(echo \"before\")\n(exit)\n(echo \"after\")"
    "z3_arch_error_recovery_unsupported_command" =>
      "(echo \"before\")\n(mystery-cmd a b)\n(echo \"after\")"
    "z3_arch_error_recovery_parse_continued" =>
      "(echo \"before\")\n(push nope)\n(echo \"after\")"
    "z3_arch_error_recovery_immediate_exit" =>
      "(set-option :error-behavior immediate-exit)\n(echo \"before\")\n(push nope)\n(echo \"after\")"
    _ => abort("missing z3_arch fixture input: \{id}")
  }
}

///|
fn z3_arch_fixture_expected_stdout(id : String) -> String {
  match id {
    "z3_arch_bool_incremental" => "unsat\nsat\n"
    "z3_arch_assumptions_core" => "unsat\n(not p)\n"
    "z3_arch_let_bool" => "unsat\n"
    "z3_arch_let_euf" => "unsat\n"
    "z3_arch_define_fun_bool" => "unsat\n"
    "z3_arch_model_eval" => "sat\n((p true) ((not p) false))\ntrue\ntrue\n"
    "z3_arch_eval_completion" =>
      "sat\nerror: eval is not available: unknown(model-eval-failed)\n@U0\n"
    "z3_arch_eval_availability" =>
      "error: model production is disabled\nerror: eval is not available: no-current-result\nsat\ntrue\n"
    "z3_arch_model_query_availability" =>
      "error: model is not available: no-current-result\nerror: value is not available: no-current-result\nsat\nerror: eval is not available: unknown(model-eval-failed)\n"
    "z3_arch_model_query_stale" =>
      "sat\nerror: model is not available: stale\nsat\nerror: value is not available: stale\nsat\nerror: eval is not available: stale\n"
    "z3_arch_model_repeated_scoped" =>
      "sat\n(\n  (define-fun p () Bool\n    true)\n)\n(\n  (define-fun p () Bool\n    true)\n)\nunsat\nsat\n(\n  (define-fun p () Bool\n    true)\n)\n"
    "z3_arch_model_euf_constants" =>
      "sat\n(\n  ;; universe U: @U0 @U1\n  (declare-fun @U0 () U)\n  (declare-fun @U1 () U)\n  ;; cardinality constraint for U\n  (forall ((x U)) (or (= x @U0) (= x @U1)))\n  (define-fun a () U\n    @U0)\n  (define-fun b () U\n    @U1)\n)\n"
    "z3_arch_model_partial_unary_uf" =>
      "sat\n(\n  ;; universe U: @U0 @U1\n  (declare-fun @U0 () U)\n  (declare-fun @U1 () U)\n  ;; cardinality constraint for U\n  (forall ((x U)) (or (= x @U0) (= x @U1)))\n  (define-fun a () U\n    @U0)\n  (define-fun b () U\n    @U1)\n  (define-fun f ((x0 U)) U\n    (ite (= x0 @U0)\n      @U1\n      #unspecified))\n)\n"
    "z3_arch_get_value_partial_uf_completion" => "sat\n(((f c) @U3))\n"
    "z3_arch_proof_modes" =>
      "unsat\nerror: proof production is disabled\nunsat\nproof#0(ast)\n"
    "z3_arch_proof_availability" =>
      "error: proof is not available: no-current-result\nsat\nerror: proof is not available: wrong-result(expected=unsat, actual=sat)\nerror: proof is not available: stale\n"
    "z3_arch_unsat_query_availability" =>
      "error: unsat core is not available: no-current-result\nerror: unsat assumptions are not available: no-current-result\nsat\nerror: unsat core is not available: wrong-result(expected=unsat, actual=sat)\nerror: unsat assumptions are not available: wrong-result(expected=unsat, actual=sat)\nerror: unsat core is not available: stale\nerror: unsat assumptions are not available: stale\n"
    "z3_arch_unknown_unsupported" =>
      "unsupported: quantifiers are not supported in Bool+EUF milestone"
    "z3_arch_unsupported_array_sort" =>
      "unsupported: arrays are not supported in Bool+EUF milestone"
    "z3_arch_unsupported_array_select_store" =>
      "unsupported: arrays are not supported in Bool+EUF milestone"
    "z3_arch_unsupported_bv_sort" =>
      "unsupported: bit-vectors are not supported in Bool+EUF milestone"
    "z3_arch_unsupported_bv_literal" =>
      "unsupported: bit-vectors are not supported in Bool+EUF milestone"
    "z3_arch_unsupported_bv_indexed_op" =>
      "unsupported: bit-vectors are not supported in Bool+EUF milestone"
    "z3_arch_unsupported_datatype_decl" =>
      "unsupported: datatypes are not supported in Bool+EUF milestone"
    "z3_arch_unsupported_datatype_constructor" =>
      "unsupported: datatypes are not supported in Bool+EUF milestone"
    "z3_arch_unsupported_datatype_match" =>
      "unsupported: datatypes are not supported in Bool+EUF milestone"
    "z3_arch_unsupported_string_sort" =>
      "unsupported: strings are not supported in Bool+EUF milestone"
    "z3_arch_unsupported_string_literal" =>
      "unsupported: strings are not supported in Bool+EUF milestone"
    "z3_arch_unsupported_seq_op" =>
      "unsupported: strings are not supported in Bool+EUF milestone"
    "z3_arch_unsupported_exists" =>
      "unsupported: quantifiers are not supported in Bool+EUF milestone"
    "z3_arch_unsupported_reserved_identifier" =>
      "unsupported: reserved identifiers are not supported in Bool+EUF milestone"
    "z3_arch_unsupported_define_fun_nonnullary" =>
      "unsupported: only nullary Bool define-fun is supported"
    "z3_arch_unsupported_parametric_sort" =>
      "unsupported: sort arity is not supported"
    "z3_arch_global_decls_default" => "type: undeclared symbol: p"
    "z3_arch_global_decls_enabled" => "sat\ntrue\n"
    "z3_arch_global_declarations_alias" => "sat\ntrue\n"
    "z3_arch_global_decls_late_set" =>
      "solver: cannot set :global-decls while scopes are active"
    "z3_arch_global_declarations_alias_late_set" =>
      "solver: cannot set :global-decls while scopes are active"
    "z3_arch_global_decls_reset" => "true\nsat\n"
    "z3_arch_pop_underflow" => "solver: invalid-pop"
    "z3_arch_pop_over_scope" => "solver: invalid-pop"
    "z3_arch_builtin_option_storage" =>
      "true\n0\n0\nfalse\ntrue\ncontinued-execution\nfalse\n3\n11\ntrue\nfalse\nimmediate-exit\n(:error-behavior immediate-exit)\n"
    "z3_arch_builtin_options_reset" =>
      "success\nsuccess\nsuccess\nsuccess\nsuccess\nsuccess\nsuccess\nsuccess\nsuccess\nsuccess\nsuccess\nsuccess\ntrue\ntrue\ntrue\ntrue\ntrue\n\"stdout\"\n\"stderr\"\n3\n11\nfalse\nimmediate-exit\n"
    "z3_arch_auto_config_option" => "false\ntrue\ntrue\n"
    "z3_arch_reproducible_resource_limit_option" => "0\n7\n7\n"
    "z3_arch_builtin_option_invalid_value" =>
      "0\n(error \":verbosity expects a non-negative integer\")\n0\nafter\n"
    "z3_arch_builtin_option_invalid_bool_enum" =>
      "true\n(error \":print-warning expects true or false\")\ntrue\ncontinued-execution\n(error \":error-behavior expects continued-execution or immediate-exit\")\ncontinued-execution\nafter\n"
    "z3_arch_unsupported_set_option" =>
      "unsupported: unsupported option: :smt.relevancy"
    "z3_arch_unsupported_get_option" =>
      "unsupported: unsupported option: :smt.relevancy"
    "z3_arch_set_info_print_success" =>
      "success\nsuccess\n(:error-behavior continued-execution)\n"
    "z3_arch_unsupported_get_info" => "unsupported: unsupported get-info: :name"
    "z3_arch_info_statistics_rlimit" =>
      "(:rlimit 1)\nsat\n(:all-statistics solver.checks)\n(:rlimit 5)\n"
    "z3_arch_info_statistics_no_check" =>
      "(:all-statistics)\n(:rlimit 2)\n(:rlimit 3)\n"
    "z3_arch_info_reason_unknown_default" =>
      "(:reason-unknown no-current-result)\nsat\n(:reason-unknown no-current-result)\n(:reason-unknown stale)\n"
    "z3_arch_info_reason_unknown_unsat" =>
      "unsat\n(:reason-unknown no-current-result)\n"
    "z3_arch_reset_clears_reason_unknown" =>
      "sat\n(:reason-unknown no-current-result)\nsat\n(:reason-unknown no-current-result)\n"
    "z3_arch_custom_statistics_incomplete" =>
      "(:all-statistics backend.custom :incomplete-reasons incomplete-theory(stats),statistics-missing-owner:backend.custom)\n"
    "z3_arch_custom_statistics_schema" =>
      "prefix:(:all-statistics\nkey:backend.custom\nreason:incomplete-theory(stats)\nreason:statistics-missing-owner:backend.custom\n"
    "z3_arch_custom_unknown_with_model" =>
      "unknown: maybe\n(\n  (define-fun p () Bool\n    true)\n)\n((p true))\ntrue\n(:reason-unknown maybe)\n"
    "z3_arch_custom_unknown_no_model" =>
      "unknown: maybe\nerror: model is not available: wrong-result(expected=sat, actual=unknown-no-model)\nerror: eval is not available: wrong-result(expected=sat, actual=unknown-no-model)\n(:reason-unknown maybe)\n"
    "z3_arch_custom_timeout_reason" =>
      "unknown: timeout\n(:reason-unknown timeout)\n"
    "z3_arch_custom_memout_reason" =>
      "unknown: memout\n(:reason-unknown memout)\n"
    "z3_arch_custom_max_conflicts_reason" =>
      "unknown: max-conflicts\n(:reason-unknown max-conflicts)\n"
    "z3_arch_custom_resource_limit_reason" =>
      "unknown: resource-limit-exceeded\n(:reason-unknown resource-limit-exceeded)\n"
    "z3_arch_custom_canceled_reason" =>
      "unknown: canceled(api)\n(:reason-unknown canceled(api))\n"
    "z3_arch_custom_unsupported_fragment_reason" =>
      "unknown: unsupported-fragment(array)\n(:reason-unknown unsupported-fragment(array))\n"
    "z3_arch_custom_invalid_core_reason" =>
      "unknown: invalid-core\n(:reason-unknown invalid-core)\n"
    "z3_arch_custom_invalid_proof_reason" =>
      "unknown: invalid-proof\n(:reason-unknown invalid-proof)\n"
    "z3_arch_custom_invalid_model_reason" =>
      "unknown: invalid-model\n(:reason-unknown invalid-model)\n"
    "z3_arch_custom_incomplete_theory_reason" =>
      "unknown: incomplete-theory(fake)\n(:reason-unknown incomplete-theory(fake))\n"
    "z3_arch_custom_incomplete_quantifiers_reason" =>
      "unknown: incomplete-quantifiers\n(:reason-unknown incomplete-quantifiers)\n"
    "z3_arch_custom_incomplete_lambdas_reason" =>
      "unknown: incomplete-lambdas\n(:reason-unknown incomplete-lambdas)\n"
    "z3_arch_produce_flags_disabled" =>
      "unsat\nerror: model production is disabled\nerror: proof production is disabled\nerror: unsat core production is disabled\nunsat\nerror: unsat assumption production is disabled\n"
    "z3_arch_produce_models_late_enable" =>
      "sat\n(\n  (define-fun p () Bool\n    true)\n)\n"
    "z3_arch_produce_proofs_late_set" => "solver: late-option:produce_proofs"
    "z3_arch_produce_unsat_cores_late_set" =>
      "solver: late-option:produce_unsat_cores"
    "z3_arch_produce_unsat_assumptions_late_set" =>
      "solver: late-option:produce_unsat_assumptions"
    "z3_arch_reset_assertions_reopens_produce_flags" =>
      "unsat\nproof#0(ast)\ncore-p\ncore-p\n"
    "z3_arch_reset_assertions_scope_replay" => "sat\nsat\n"
    "z3_arch_reset_reopens_produce_flags" =>
      "unsat\nproof#0(ast)\ncore-p\ncore-p\n"
    "z3_arch_reset_clears_macro_env" => "sat\ntype: undeclared symbol: m\n"
    "z3_arch_set_logic_ordering" =>
      "solver: cannot set logic after assertions have been added"
    "z3_arch_set_logic_duplicate" => "solver: logic is already set"
    "z3_arch_unsupported_logic_recovery" =>
      "unsupported: unsupported logic: QF_BOOL\nsat\n"
    "z3_arch_set_logic_option_ordering" =>
      "success\nsuccess\nsuccess\nsuccess\nsuccess\nsuccess\nsuccess\nsuccess\nsuccess\nsat\n(\n  (define-fun p () Bool\n    true)\n)\n"
    "z3_arch_exit_stops_runner" => "before\n"
    "z3_arch_error_recovery_unsupported_command" =>
      "before\nunsupported: unsupported command: mystery-cmd\nafter\n"
    "z3_arch_error_recovery_parse_continued" =>
      "before\n(error \"push count must be non-negative\")\nafter\n"
    "z3_arch_error_recovery_immediate_exit" =>
      "before\n(error \"push count must be non-negative\")\n"
    _ => abort("missing z3_arch expected stdout: \{id}")
  }
}

///|
fn z3_arch_has_manifest_entry(
  entries : Array[Z3ArchManifestEntry],
  id : String,
) -> Bool {
  for entry in entries {
    if entry.id == id {
      return true
    }
  }
  false
}

///|
fn z3_arch_validate_manifest_entry(entry : Z3ArchManifestEntry) -> Unit raise {
  if entry.command_count.is_empty() {
    fail("manifest command count is empty: \{entry.id}")
  }
  if entry.command_kind.is_empty() {
    fail("manifest command kind is empty: \{entry.id}")
  }
  if entry.support_status.is_empty() {
    fail("manifest support status is empty: \{entry.id}")
  }
  if entry.syntax_family.is_empty() {
    fail("manifest syntax family is empty: \{entry.id}")
  }
  if entry.reject_stage.is_empty() {
    fail("manifest reject stage is empty: \{entry.id}")
  }
  if entry.status_category.is_empty() {
    fail("manifest status category is empty: \{entry.id}")
  }
  if entry.reason_unknown.is_empty() {
    fail("manifest reason-unknown field is empty: \{entry.id}")
  }
  if entry.diagnostic.is_empty() {
    fail("manifest diagnostic field is empty: \{entry.id}")
  }
  if entry.z3_expected.is_empty() {
    fail("manifest Z3 expected field is empty: \{entry.id}")
  }
  if entry.z3_diff_reason.is_empty() {
    fail("manifest Z3 diff reason is empty: \{entry.id}")
  }
  if entry.expected_exit_code != "0" && entry.expected_exit_code != "1" {
    fail("seed parser-runner fixture expects exit code 0 or 1: \{entry.id}")
  }
  if !z3_arch_normalization_supported(entry.normalization) {
    fail("unsupported parser-runner normalization: \{entry.id}")
  }
  if entry.expected_stdout != "smt2/\{entry.id}.expected.out" {
    fail("manifest expected stdout path does not match fixture id: \{entry.id}")
  }
  if entry.input_file != "smt2/\{entry.id}.smt2" {
    fail("manifest input path does not match fixture id: \{entry.id}")
  }
  if entry.expected_stderr != "" &&
    entry.expected_stderr != "smt2/\{entry.id}.expected.err" {
    fail("manifest expected stderr path does not match fixture id: \{entry.id}")
  }
}

///|
fn z3_arch_validate_parser_runner_entry(
  entry : Z3ArchManifestEntry,
) -> Unit raise {
  z3_arch_validate_manifest_entry(entry)
  if !entry.runner_modes.contains("parser-runner") {
    fail("manifest row does not enable parser-runner mode: \{entry.id}")
  }
  if entry.expected_stderr != "" {
    fail("parser-runner fixture cannot validate stderr: \{entry.id}")
  }
}

///|
fn z3_arch_parse_command_count(entry : Z3ArchManifestEntry) -> Int raise {
  if entry.command_count.is_empty() {
    fail("manifest command count is empty: \{entry.id}")
  }
  let mut result = 0
  for c in entry.command_count {
    if c < '0' || c > '9' {
      fail("manifest command count is not numeric: \{entry.id}")
    }
    result = result * 10 + (c.to_int() - '0'.to_int())
  }
  result
}

///|
fn z3_arch_output_allowed(
  entry : Z3ArchManifestEntry,
  output : String,
) -> Unit raise {
  if !entry.allow_unsupported && output.contains("unsupported") {
    fail("supported fixture emitted unsupported: \{entry.id}")
  }
  if !entry.allow_unknown {
    for raw_line in output.split("\n") {
      let line = raw_line.trim().to_owned()
      if line == "unknown" || line.has_prefix("unknown: ") {
        fail(
          "fixture emitted unknown check result without manifest permission: \{entry.id}",
        )
      }
    }
  }
}

///|
fn z3_arch_allow_flags_valid(entry : Z3ArchManifestEntry) -> Bool {
  if entry.allow_unknown && entry.support_status != "supported-unknown" {
    return false
  }
  if entry.allow_unsupported {
    entry.support_status == "explicit-unsupported" ||
    entry.support_status == "supported-unknown" ||
    entry.status_category == "unsupported-command"
  } else {
    true
  }
}

///|
fn run_z3_arch_fixture(id : String, input : String) -> Smt2RunResult {
  run_smt2_result_with_factory(input, z3_arch_fixture_factory(id))
}

///|
test "z3_arch_manifest_parses_and_covers_embedded_seed_fixtures" {
  let entries = parse_z3_arch_manifest(z3_arch_disk_manifest_text())
  let embedded_entries = parse_z3_arch_manifest(z3_arch_manifest_text())
  let ids = z3_arch_fixture_ids()
  assert_true(entries.length() > 0)
  assert_true(embedded_entries.length() > 0)
  assert_true(ids.length() > 0)
  inspect(entries.length(), content="91")
  inspect(embedded_entries.length(), content="91")
  inspect(ids.length(), content="89")
  for id in ids {
    if !z3_arch_has_manifest_entry(entries, id) {
      fail("disk manifest is missing fixture id: \{id}")
    }
    if !z3_arch_has_manifest_entry(embedded_entries, id) {
      fail("embedded manifest is missing fixture id: \{id}")
    }
  }
  for entry in entries {
    if !z3_arch_has_manifest_entry(embedded_entries, entry.id) {
      fail("embedded manifest is missing disk fixture id: \{entry.id}")
    }
  }
}

///|
test "z3_arch_embedded_manifest_text_matches_disk_manifest" {
  if z3_arch_trim_final_newlines(z3_arch_manifest_text()) !=
    z3_arch_trim_final_newlines(z3_arch_disk_manifest_text()) {
    fail("embedded z3_arch manifest text diverged from disk manifest")
  }
}

///|
test "z3_arch_embedded_fixture_copy_matches_disk_files" {
  let entries = parse_z3_arch_manifest(z3_arch_disk_manifest_text())
  for entry in entries {
    z3_arch_validate_manifest_entry(entry)
    if entry.runner_modes.contains("parser-runner") {
      let disk_input = z3_arch_read_file(entry.input_file)
      let disk_expected = z3_arch_read_file(entry.expected_stdout)
      inspect(
        z3_arch_trim_final_newlines(disk_input),
        content=z3_arch_trim_final_newlines(z3_arch_fixture_input(entry.id)),
      )
      inspect(
        z3_arch_normalize_transcript(disk_expected),
        content=z3_arch_normalize_transcript(
          z3_arch_fixture_expected_stdout(entry.id),
        ),
      )
    }
  }
}

///|
test "z3_arch_manifest_command_counts_match_fixture_inputs" {
  let entries = parse_z3_arch_manifest(z3_arch_disk_manifest_text())
  inspect(entries.length(), content="91")
  for entry in entries {
    let input = z3_arch_read_file(entry.input_file)
    let expected_count = z3_arch_parse_command_count(entry)
    let actual_count = parse_program(input).length()
    if actual_count != expected_count {
      fail(
        "manifest command count mismatch for \{entry.id}: expected \{expected_count}, actual \{actual_count}",
      )
    }
  }
}

///|
test "z3_arch_manifest_allow_flags_match_status_and_expected_output" {
  let entries = parse_z3_arch_manifest(z3_arch_disk_manifest_text())
  inspect(entries.length(), content="91")
  for entry in entries {
    if !z3_arch_allow_flags_valid(entry) {
      fail("manifest allow flags do not match support status: \{entry.id}")
    }
    let expected = z3_arch_read_file(entry.expected_stdout)
    z3_arch_output_allowed(entry, expected)
  }
}

///|
test "z3_arch_parser_runner_disk_fixtures_match_expected_stdout" {
  let entries = parse_z3_arch_manifest(z3_arch_disk_manifest_text())
  let mut parser_runner_count = 0
  for entry in entries {
    z3_arch_validate_manifest_entry(entry)
    if entry.runner_modes.contains("parser-runner") {
      z3_arch_validate_parser_runner_entry(entry)
      let input = z3_arch_read_file(entry.input_file)
      let expected = z3_arch_read_file(entry.expected_stdout)
      let result = run_z3_arch_fixture(entry.id, input)
      let output = result.output()
      z3_arch_output_allowed(entry, output)
      parser_runner_count += 1
      z3_arch_compare_transcript(entry, output, expected)
      inspect("\{result.exit_code()}", content=entry.expected_exit_code)
    }
  }
  inspect(parser_runner_count, content="89")
}
