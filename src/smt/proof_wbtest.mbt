///|
fn unit_availability_text(value : @util.Availability[Unit]) -> String {
  match value {
    @util.Available(_) => "available"
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn proof_assumption_result_text(result : SmtContextAssumptionResult) -> String {
  match result {
    SmtAssumptionSat => "sat"
    SmtAssumptionUnsat(_, _) => "unsat"
    SmtAssumptionUnknown(reason) => "unknown: \{reason}"
  }
}

///|
fn proof_u_const(
  manager : @ast.AstManager,
  sort : @util.SortId,
  name : String,
) -> @util.ExprId raise {
  let decl = manager.declare_const(name, sort)
  manager.mk_app(decl, [])
}

///|
fn proof_unary_app(
  manager : @ast.AstManager,
  decl : @util.FuncDeclId,
  arg : @util.ExprId,
) -> @util.ExprId raise {
  manager.mk_app(decl, [arg])
}

///|
test "smt_context_theory_actions_lazy_materialize_antecedents" {
  let owner = @theory_ids.TheoryId::new(41)
  let antecedent = @theory_core.AntecedentId::new(owner, 0, scope_generation=0)
  let expected = @pure_sat.Literal::neg(@pure_sat.BoolVar::new(2))
  let log : Array[String] = []
  let context = SmtContext::new(@ast.AstManager::new())
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    owner,
    "proof-fake",
    [@ast.FamilyId::new(41)],
  )
  plugin.set_get_antecedents(fn(requested) {
    log.push("query:\{requested}")
    if requested == antecedent {
      [expected]
    } else {
      []
    }
  })
  plugin.set_theory_check(fn(_, actions) {
    let literals = actions.materialize_antecedent(antecedent)
    log.push([ for literal in literals => "\{literal}" ].join(","))
    @theory_core.TheoryCheckDone
  })
  context.register_theory(plugin)
  ignore(context.check_sat())
  inspect(log.join(">"), content="query:th#41:antecedent#0>not b2")
}

///|
test "smt_context_theory_actions_allocate_scoped_proof_hints" {
  let owner = @theory_ids.TheoryId::new(42)
  let log : Array[String] = []
  let context = SmtContext::new(@ast.AstManager::new())
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    owner,
    "proof-hint-fake",
    [@ast.FamilyId::new(42)],
  )
  plugin.set_theory_check(fn(_, actions) {
    let hint = actions.create_proof_hint(owner, "congruence")
    log.push("\{hint}:\{hint.is_valid_at(actions.scope_depth())}")
    @theory_core.TheoryCheckDone
  })
  context.register_theory(plugin)
  ignore(context.check_sat())
  inspect(log.join(">"), content="th#42:proof-hint#0:true")
  inspect(
    context.proof_hint_log_text(),
    content="th#42:proof-hint#0:congruence",
  )
}

///|
test "smt_context_theory_enqueue_reaches_sat_extension_conflict" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let not_p = manager.mk_not(p)
  let context = SmtContext::new(manager)
  context.assert_expr(not_p)
  let p_literal = @pure_sat.Literal::pos(@pure_sat.BoolVar::new(1))
  let owner = @theory_ids.TheoryId::new(43)
  let antecedent = @theory_core.AntecedentId::new(owner, 0, scope_generation=0)
  let log : Array[String] = []
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    owner,
    "sat-bridge",
    [@ast.FamilyId::new(43)],
  )
  plugin.set_can_propagate(fn(_) { true })
  plugin.set_propagate(fn(_, actions) {
    match actions.internalize_bool(p) {
      Some(literal) => actions.enqueue(literal, antecedent)
      None => log.push("missing-internalize")
    }
    @theory_core.TheoryPropagateDone
  })
  plugin.set_get_antecedents(fn(requested) {
    log.push("query:\{requested}")
    if requested == antecedent {
      [p_literal]
    } else {
      []
    }
  })
  context.register_theory(plugin)
  inspect(theory_lifecycle_result_text(context.check_sat()), content="unsat")
  inspect(log.join(">"), content="query:th#43:antecedent#0")
  inspect(
    context.sat_clause_event_log_text(),
    content=(
      #|add clause#0 asserted input;add clause#1 theory sat-bridge redundant
    ),
  )
}

///|
test "smt_context_theory_add_clause_reaches_sat_core" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  let owner = @theory_ids.TheoryId::new(44)
  let mut rounds = 0
  let log : Array[String] = []
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    owner,
    "clause-bridge",
    [@ast.FamilyId::new(44)],
  )
  plugin.set_theory_check(fn(_, actions) {
    rounds += 1
    if rounds == 1 {
      match actions.internalize_bool(p) {
        Some(literal) => actions.add_clause([literal.negate()])
        None => log.push("missing-internalize")
      }
      @theory_core.TheoryCheckContinue
    } else {
      @theory_core.TheoryCheckDone
    }
  })
  context.register_theory(plugin)
  inspect(theory_lifecycle_result_text(context.check_sat()), content="unsat")
  inspect(log.join(">"), content="")
  inspect(
    context.sat_clause_event_log_text(),
    content=(
      #|add clause#0 asserted input;add clause#1 theory clause-bridge asserted;add clause#2 redundant learned
    ),
  )
}

///|
test "smt_context_theory_add_lemma_reaches_sat_core" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  let owner = @theory_ids.TheoryId::new(45)
  let mut rounds = 0
  let log : Array[String] = []
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    owner,
    "lemma-bridge",
    [@ast.FamilyId::new(45)],
  )
  plugin.set_theory_check(fn(_, actions) {
    rounds += 1
    if rounds == 1 {
      match actions.internalize_bool(p) {
        Some(literal) => actions.add_lemma([literal.negate()])
        None => log.push("missing-internalize")
      }
      @theory_core.TheoryCheckContinue
    } else {
      @theory_core.TheoryCheckDone
    }
  })
  context.register_theory(plugin)
  inspect(theory_lifecycle_result_text(context.check_sat()), content="unsat")
  inspect(log.join(">"), content="")
  inspect(
    context.sat_clause_event_log_text(),
    content=(
      #|add clause#0 asserted input;add clause#1 theory lemma-bridge redundant;add clause#2 redundant learned
    ),
  )
}

///|
test "smt_context_proof_checker_rejects_unhinted_theory_lemma" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  let owner = @theory_ids.TheoryId::new(51)
  let mut rounds = 0
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    owner,
    "unhinted-lemma-bridge",
    [@ast.FamilyId::new(51)],
  )
  plugin.set_theory_check(fn(_, actions) {
    rounds += 1
    if rounds == 1 {
      match actions.internalize_bool(p) {
        Some(literal) => actions.add_lemma([literal.negate()])
        None => ()
      }
      @theory_core.TheoryCheckContinue
    } else {
      @theory_core.TheoryCheckDone
    }
  })
  context.register_theory(plugin)
  inspect(theory_lifecycle_result_text(context.check_sat()), content="unsat")
  let proof = context.proof_object()
  inspect(
    proof.root_text(),
    content=(
      #|sat-events:add clause#0 asserted input;add clause#1 theory unhinted-lemma-bridge redundant;add clause#2 redundant learned;final-empty:true;result:unsat
    ),
  )
  inspect(
    unit_availability_text(context.check_proof_object(proof)),
    content="unknown(invalid-proof)",
  )
}

///|
test "smt_context_theory_add_lemma_with_hint_reaches_sat_core" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  let owner = @theory_ids.TheoryId::new(48)
  let mut rounds = 0
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    owner,
    "lemma-hint-bridge",
    [@ast.FamilyId::new(48)],
  )
  plugin.set_theory_check(fn(_, actions) {
    rounds += 1
    if rounds == 1 {
      match actions.internalize_bool(p) {
        Some(literal) => {
          let hint = actions.create_proof_hint(owner, "congruence")
          actions.add_lemma_with_hint([literal.negate()], hint)
        }
        None => ()
      }
      @theory_core.TheoryCheckContinue
    } else {
      @theory_core.TheoryCheckDone
    }
  })
  context.register_theory(plugin)
  inspect(theory_lifecycle_result_text(context.check_sat()), content="unsat")
  inspect(
    context.sat_clause_event_log_text(),
    content=(
      #|add clause#0 asserted input;add clause#1 theory lemma-hint-bridge redundant hint congruence;add clause#2 redundant learned
    ),
  )
}

///|
test "smt_context_proof_object_carries_theory_lemma_hints" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  let owner = @theory_ids.TheoryId::new(49)
  let mut rounds = 0
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    owner,
    "proof-object-hint-bridge",
    [@ast.FamilyId::new(49)],
  )
  plugin.set_theory_check(fn(_, actions) {
    rounds += 1
    if rounds == 1 {
      match actions.internalize_bool(p) {
        Some(literal) => {
          let hint = actions.create_proof_hint(owner, "congruence")
          actions.add_lemma_with_hint([literal.negate()], hint)
        }
        None => ()
      }
      @theory_core.TheoryCheckContinue
    } else {
      @theory_core.TheoryCheckDone
    }
  })
  context.register_theory(plugin)
  inspect(theory_lifecycle_result_text(context.check_sat()), content="unsat")
  let proof = context.proof_object()
  inspect(
    proof.root_text(),
    content=(
      #|sat-events:add clause#0 asserted input;add clause#1 theory proof-object-hint-bridge redundant hint congruence;add clause#2 redundant learned;final-empty:true;result:unsat
    ),
  )
  let hints = proof.hints()
  inspect(hints.length(), content="1")
  inspect(hints[0].owner_text(), content="proof-object-hint-bridge")
  inspect(hints[0].kind_text(), content="congruence")
}

///|
test "smt_context_proof_checker_rejects_tampered_sat_event_stream" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  context.assert_expr(manager.mk_not(p))
  inspect(theory_lifecycle_result_text(context.check_sat()), content="unsat")
  let proof = context.proof_object()
  inspect(
    unit_availability_text(context.check_proof_object(proof)),
    content="available",
  )
  let tampered = @proof.ProofObject::from_root_and_hints(
    "sat-events:add clause#999 asserted input",
    proof.hints(),
  )
  inspect(
    unit_availability_text(context.check_proof_object(tampered)),
    content="unknown(invalid-proof)",
  )
}

///|
test "smt_context_proof_root_records_final_empty_clause" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  context.assert_expr(manager.mk_not(p))
  inspect(theory_lifecycle_result_text(context.check_sat()), content="unsat")
  let proof = context.proof_object()
  inspect(
    proof.root_text(),
    content=(
      #|sat-events:add clause#0 asserted input;add clause#1 asserted input;add clause#2 redundant learned;final-empty:true;result:unsat
    ),
  )
  inspect(
    unit_availability_text(context.check_proof_object(proof)),
    content="available",
  )
}

///|
test "smt_context_empty_assumption_check_preserves_assertion_proof_root" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  context.assert_expr(manager.mk_not(p))
  inspect(
    proof_assumption_result_text(context.check_sat_assuming([])),
    content="unsat",
  )
  let proof = context.proof_object()
  inspect(
    proof.root_text(),
    content=(
      #|sat-events:add clause#0 asserted input;add clause#1 asserted input;add clause#2 redundant learned;final-empty:true;result:unsat
    ),
  )
  inspect(
    unit_availability_text(context.check_proof_object(proof)),
    content="available",
  )
}

///|
test "smt_context_proof_checker_rejects_proof_after_late_theory_registration" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  context.assert_expr(manager.mk_not(p))
  inspect(theory_lifecycle_result_text(context.check_sat()), content="unsat")
  let proof = context.proof_object()
  inspect(
    unit_availability_text(context.check_proof_object(proof)),
    content="available",
  )
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    @theory_ids.TheoryId::new(53),
    "late-proof-stale",
    [@ast.FamilyId::new(53)],
  )
  context.register_theory(plugin)
  inspect(
    unit_availability_text(context.check_proof_object(proof)),
    content="unknown(invalid-proof)",
  )
}

///|
test "smt_context_proof_checker_requires_unsat_theorem_marker" {
  let context = SmtContext::new(@ast.AstManager::new())
  inspect(theory_lifecycle_result_text(context.check_sat()), content="sat")
  let proof = context.proof_object()
  inspect(
    unit_availability_text(context.check_proof_object(proof)),
    content="unknown(invalid-proof)",
  )
}

///|
test "smt_context_proof_checker_rejects_euf_unsat_without_materialized_proof" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a = proof_u_const(manager, u, "a")
  let b = proof_u_const(manager, u, "b")
  let f = manager.declare_fun("f", [u], u)
  let f_a = proof_unary_app(manager, f, a)
  let f_b = proof_unary_app(manager, f, b)
  let context = SmtContext::new(manager)
  context.assert_expr(manager.mk_eq(a, b))
  context.assert_expr(manager.mk_distinct([f_a, f_b]))
  inspect(theory_lifecycle_result_text(context.check_sat()), content="unsat")
  let proof = context.proof_object()
  inspect(
    proof.root_text(),
    content="sat-events:;final-empty:false;result:unsat",
  )
  inspect(
    unit_availability_text(context.check_proof_object(proof)),
    content="unknown(invalid-proof)",
  )
}

///|
test "smt_context_proof_checker_rejects_tampered_theory_hint" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  let owner = @theory_ids.TheoryId::new(50)
  let mut rounds = 0
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    owner,
    "proof-checker-hint-bridge",
    [@ast.FamilyId::new(50)],
  )
  plugin.set_theory_check(fn(_, actions) {
    rounds += 1
    if rounds == 1 {
      match actions.internalize_bool(p) {
        Some(literal) => {
          let hint = actions.create_proof_hint(owner, "congruence")
          actions.add_lemma_with_hint([literal.negate()], hint)
        }
        None => ()
      }
      @theory_core.TheoryCheckContinue
    } else {
      @theory_core.TheoryCheckDone
    }
  })
  context.register_theory(plugin)
  inspect(theory_lifecycle_result_text(context.check_sat()), content="unsat")
  let proof = context.proof_object()
  inspect(
    unit_availability_text(context.check_proof_object(proof)),
    content="available",
  )
  let tampered = @proof.ProofObject::from_root_and_hints(proof.root_text(), [
    @proof.ProofHint::with_owner("proof-checker-hint-bridge", "bad"),
  ])
  inspect(
    unit_availability_text(context.check_proof_object(tampered)),
    content="unknown(invalid-proof)",
  )
}

///|
test "smt_context_proof_checker_rejects_unsupported_theory_hint_kind" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  let owner = @theory_ids.TheoryId::new(52)
  let mut rounds = 0
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    owner,
    "unsupported-hint-bridge",
    [@ast.FamilyId::new(52)],
  )
  plugin.set_theory_check(fn(_, actions) {
    rounds += 1
    if rounds == 1 {
      match actions.internalize_bool(p) {
        Some(literal) => {
          let hint = actions.create_proof_hint(owner, "bad-euf-rule")
          actions.add_lemma_with_hint([literal.negate()], hint)
        }
        None => ()
      }
      @theory_core.TheoryCheckContinue
    } else {
      @theory_core.TheoryCheckDone
    }
  })
  context.register_theory(plugin)
  inspect(theory_lifecycle_result_text(context.check_sat()), content="unsat")
  let proof = context.proof_object()
  let hints = proof.hints()
  inspect(hints.length(), content="1")
  inspect(hints[0].kind_text(), content="bad-euf-rule")
  inspect(
    unit_availability_text(context.check_proof_object(proof)),
    content="unknown(invalid-proof)",
  )
}

///|
test "smt_context_proof_checker_rejects_malformed_congruence_hint_kind" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  let owner = @theory_ids.TheoryId::new(54)
  let mut rounds = 0
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    owner,
    "malformed-hint-bridge",
    [@ast.FamilyId::new(54)],
  )
  plugin.set_theory_check(fn(_, actions) {
    rounds += 1
    if rounds == 1 {
      match actions.internalize_bool(p) {
        Some(literal) => {
          let hint = actions.create_proof_hint(owner, "congruence((= a b)")
          actions.add_lemma_with_hint([literal.negate()], hint)
        }
        None => ()
      }
      @theory_core.TheoryCheckContinue
    } else {
      @theory_core.TheoryCheckDone
    }
  })
  context.register_theory(plugin)
  inspect(theory_lifecycle_result_text(context.check_sat()), content="unsat")
  let proof = context.proof_object()
  let hints = proof.hints()
  inspect(hints.length(), content="1")
  inspect(hints[0].kind_text(), content="congruence((= a b)")
  inspect(
    unit_availability_text(context.check_proof_object(proof)),
    content="unknown(invalid-proof)",
  )
}

///|
test "smt_context_proof_checker_rejects_single_argument_congruence_hint" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  let owner = @theory_ids.TheoryId::new(55)
  let mut rounds = 0
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    owner,
    "single-arg-hint-bridge",
    [@ast.FamilyId::new(55)],
  )
  plugin.set_theory_check(fn(_, actions) {
    rounds += 1
    if rounds == 1 {
      match actions.internalize_bool(p) {
        Some(literal) => {
          let hint = actions.create_proof_hint(owner, "congruence((= a b))")
          actions.add_lemma_with_hint([literal.negate()], hint)
        }
        None => ()
      }
      @theory_core.TheoryCheckContinue
    } else {
      @theory_core.TheoryCheckDone
    }
  })
  context.register_theory(plugin)
  inspect(theory_lifecycle_result_text(context.check_sat()), content="unsat")
  let proof = context.proof_object()
  let hints = proof.hints()
  inspect(hints.length(), content="1")
  inspect(hints[0].kind_text(), content="congruence((= a b))")
  inspect(
    unit_availability_text(context.check_proof_object(proof)),
    content="unknown(invalid-proof)",
  )
}

///|
test "smt_context_proof_checker_accepts_multi_argument_congruence_hint" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  let owner = @theory_ids.TheoryId::new(56)
  let mut rounds = 0
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    owner,
    "multi-arg-hint-bridge",
    [@ast.FamilyId::new(56)],
  )
  plugin.set_theory_check(fn(_, actions) {
    rounds += 1
    if rounds == 1 {
      match actions.internalize_bool(p) {
        Some(literal) => {
          let hint = actions.create_proof_hint(
            owner, "congruence((= a b),(= b c),(distinct a c))",
          )
          actions.add_lemma_with_hint([literal.negate()], hint)
        }
        None => ()
      }
      @theory_core.TheoryCheckContinue
    } else {
      @theory_core.TheoryCheckDone
    }
  })
  context.register_theory(plugin)
  inspect(theory_lifecycle_result_text(context.check_sat()), content="unsat")
  let proof = context.proof_object()
  let hints = proof.hints()
  inspect(hints.length(), content="1")
  inspect(
    hints[0].kind_text(),
    content="congruence((= a b),(= b c),(distinct a c))",
  )
  inspect(
    unit_availability_text(context.check_proof_object(proof)),
    content="available",
  )
}

///|
test "smt_context_proof_checker_rejects_trailing_suffix_congruence_hint" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let p = manager.mk_app(p_decl, [])
  let context = SmtContext::new(manager)
  context.assert_expr(p)
  let owner = @theory_ids.TheoryId::new(57)
  let mut rounds = 0
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    owner,
    "trailing-suffix-hint-bridge",
    [@ast.FamilyId::new(57)],
  )
  plugin.set_theory_check(fn(_, actions) {
    rounds += 1
    if rounds == 1 {
      match actions.internalize_bool(p) {
        Some(literal) => {
          let hint = actions.create_proof_hint(
            owner, "congruence((= a b),(distinct a b))suffix",
          )
          actions.add_lemma_with_hint([literal.negate()], hint)
        }
        None => ()
      }
      @theory_core.TheoryCheckContinue
    } else {
      @theory_core.TheoryCheckDone
    }
  })
  context.register_theory(plugin)
  inspect(theory_lifecycle_result_text(context.check_sat()), content="unsat")
  let proof = context.proof_object()
  let hints = proof.hints()
  inspect(hints.length(), content="1")
  inspect(
    hints[0].kind_text(),
    content="congruence((= a b),(distinct a b))suffix",
  )
  inspect(
    unit_availability_text(context.check_proof_object(proof)),
    content="unknown(invalid-proof)",
  )
}

///|
test "smt_context_theory_conflict_reaches_sat_extension" {
  let context = SmtContext::new(@ast.AstManager::new())
  let owner = @theory_ids.TheoryId::new(46)
  let antecedent = @theory_core.AntecedentId::new(owner, 0, scope_generation=0)
  let log : Array[String] = []
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    owner,
    "conflict-bridge",
    [@ast.FamilyId::new(46)],
  )
  plugin.set_theory_check(fn(_, actions) {
    actions.conflict(antecedent)
    @theory_core.TheoryCheckDone
  })
  plugin.set_get_antecedents(fn(requested) {
    log.push("query:\{requested}")
    []
  })
  context.register_theory(plugin)
  inspect(theory_lifecycle_result_text(context.check_sat()), content="unsat")
  inspect(log.join(">"), content="query:th#46:antecedent#0")
  inspect(
    context.sat_clause_event_log_text(),
    content="add clause#0 theory conflict-bridge redundant",
  )
}

///|
test "smt_context_theory_mark_unknown_reaches_sat_extension" {
  let context = SmtContext::new(@ast.AstManager::new())
  let owner = @theory_ids.TheoryId::new(47)
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    owner,
    "unknown-bridge",
    [@ast.FamilyId::new(47)],
  )
  plugin.set_theory_check(fn(_, actions) {
    actions.mark_unknown(@util.ReasonUnknown::Other("bridge-unknown"))
    @theory_core.TheoryCheckDone
  })
  context.register_theory(plugin)
  inspect(
    theory_lifecycle_result_text(context.check_sat()),
    content="unknown:bridge-unknown",
  )
}
