///|
fn run_smt2(input : String) -> String {
  run_smt2_with_factory(input, @assembly.solver_factory())
}

///|
fn run_smt2_result(input : String) -> Smt2RunResult {
  run_smt2_result_with_factory(input, @assembly.solver_factory())
}

///|
fn expect_parse_ok(input : String, expected : String) -> Unit raise {
  let exprs = parse_program(input)
  if exprs.length() == 0 {
    abort("expected parsed expression")
  } else {
    inspect(exprs[0], content=expected)
  }
}

///|
fn expect_parse_err(input : String, expected : String) -> Unit raise {
  try {
    let exprs = parse_program(input)
    abort("expected parse diagnostic, got \{exprs.length()} expression(s)")
  } catch {
    err => inspect(err, content=expected)
  }
}

///|
fn expect_command_err(
  manager : @ast.AstManager,
  input : String,
  expected : String,
) -> Unit raise {
  try {
    let command = parse_one_command(manager, input)
    abort("expected command diagnostic, got \{command}")
  } catch {
    err => inspect(err, content=expected)
  }
}

///|
test "sexpr_skips_comments" {
  expect_parse_ok("; comment\np", "Atom(\"p\")")
}

///|
test "sexpr_parses_nested_lists" {
  expect_parse_ok(
    "; comment\n(assert (and p (not q)))", "List([Atom(\"assert\"), List([Atom(\"and\"), Atom(\"p\"), List([Atom(\"not\"), Atom(\"q\")])])])",
  )
}

///|
test "sexpr_parses_quoted_strings" {
  expect_parse_ok(
    "(echo \"a \"\"quote\"\"\")", "List([Atom(\"echo\"), StringLit(\"a \\\"quote\\\"\")])",
  )
}

///|
test "sexpr_reports_unclosed_list" {
  expect_parse_err("(assert p", "line 1, col 1: unclosed list")
}

///|
test "sexpr_reports_unclosed_string" {
  expect_parse_err("\"unterminated", "line 1, col 1: unclosed string")
}

///|
test "sexpr_reports_extra_right_paren" {
  expect_parse_err(")", "line 1, col 1: extra ')'")
}

///|
test "sexpr_cursor_parses_one_top_level_form" {
  let cursor = SExprCursor::new("(exit) \"unterminated")
  match parse_next(cursor) {
    Next(expr, next) => {
      inspect(expr, content="List([Atom(\"exit\")])")
      try {
        ignore(parse_next(next))
        inspect("missing diagnostic", content="diagnostic")
      } catch {
        err => inspect(err, content="line 1, col 8: unclosed string")
      }
    }
    End(_) => inspect("missing expression", content="expression")
  }
}

///|
fn parse_one_command(
  manager : @ast.AstManager,
  input : String,
) -> @cmd_context.Command raise {
  let exprs = parse_program(input)
  parse_command(manager, exprs[0])
}

///|
test "parse_set_logic_qf_uf" {
  let manager = @ast.AstManager::new()
  let command = parse_one_command(manager, "(set-logic QF_UF)")
  inspect(command, content="SetLogic(QF_UF)")
}

///|
test "parse_set_option_produce_models" {
  let manager = @ast.AstManager::new()
  let command = parse_one_command(manager, "(set-option :produce-models true)")
  inspect(command, content="SetOption(:produce-models, true)")
}

///|
test "parse_set_info" {
  let manager = @ast.AstManager::new()
  let command = parse_one_command(manager, "(set-info :source \"z0\")")
  inspect(command, content="SetInfo(:source, z0)")
}

///|
test "parse_reset_assertions" {
  let manager = @ast.AstManager::new()
  let command = parse_one_command(manager, "(reset-assertions)")
  inspect(command, content="ResetAssertions")
}

///|
test "parse_reset" {
  let manager = @ast.AstManager::new()
  let command = parse_one_command(manager, "(reset)")
  inspect(command, content="Reset")
}

///|
test "parse_get_option" {
  let manager = @ast.AstManager::new()
  let command = parse_one_command(manager, "(get-option :produce-models)")
  inspect(command, content="GetOption(:produce-models)")
}

///|
test "parse_declare_sort_arity_zero" {
  let manager = @ast.AstManager::new()
  let command = parse_one_command(manager, "(declare-sort U 0)")
  inspect(command, content="DeclareSort(U, 0)")
}

///|
test "parse_declare_const_bool" {
  let manager = @ast.AstManager::new()
  let command = parse_one_command(manager, "(declare-const p Bool)")
  inspect(command, content="DeclareConst(p, sort#0)")
}

///|
test "parse_declare_const_int" {
  let manager = @ast.AstManager::new()
  let command = parse_one_command(manager, "(declare-const x Int)")
  inspect(command, content="DeclareConst(x, sort#1)")
}

///|
test "parse_declare_fun_unary_bool" {
  let manager = @ast.AstManager::new()
  let command = parse_one_command(manager, "(declare-fun f (Bool) Bool)")
  inspect(command, content="DeclareFun(f, [sort#0], sort#0)")
}

///|
test "parse_define_fun_nullary_bool_macro" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  ignore(manager.mk_app(p_decl, []))
  let command = parse_one_command(manager, "(define-fun m () Bool p)")
  match command {
    DefineFun(name, params, range, body) => {
      inspect(name, content="m")
      inspect(params.length(), content="0")
      inspect(range, content="sort#0")
      inspect(manager.pretty(body), content="p")
    }
    _ => inspect(command, content="DefineFun")
  }
}

///|
test "parse_reject_nonnullary_define_fun" {
  let manager = @ast.AstManager::new()
  expect_command_err(
    manager, "(define-fun f ((x Bool)) Bool true)", "unsupported: only nullary Bool define-fun is supported",
  )
}

///|
test "parse_assert_bool_formula" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let q_decl = manager.declare_const("q", manager.bool_sort())
  ignore(manager.mk_app(p_decl, []))
  ignore(manager.mk_app(q_decl, []))
  let command = parse_one_command(manager, "(assert (and p (not q)))")
  match command {
    Assert(expr) => inspect(manager.pretty(expr), content="(and p (not q))")
    _ => inspect(command, content="Assert")
  }
}

///|
test "parse_assert_int_comparison_formula" {
  let manager = @ast.AstManager::new()
  let x_decl = manager.declare_const("x", manager.int_sort())
  ignore(manager.mk_app(x_decl, []))
  let command = parse_one_command(manager, "(assert (< 1 x))")
  match command {
    Assert(expr) => inspect(manager.pretty(expr), content="(< 1 x)")
    _ => inspect(command, content="Assert")
  }
}

///|
test "parse_assert_bool_let_formula" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let q_decl = manager.declare_const("q", manager.bool_sort())
  ignore(manager.mk_app(p_decl, []))
  ignore(manager.mk_app(q_decl, []))
  let command = parse_one_command(manager, "(assert (let ((x p)) (and x q)))")
  match command {
    Assert(expr) => inspect(manager.pretty(expr), content="(and p q)")
    _ => inspect(command, content="Assert")
  }
}

///|
test "parse_assert_euf_let_formula" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  let a_decl = manager.declare_const("a", u)
  let b_decl = manager.declare_const("b", u)
  ignore(manager.mk_app(a_decl, []))
  ignore(manager.mk_app(b_decl, []))
  let command = parse_one_command(
    manager, "(assert (let ((x a) (y b)) (= x y)))",
  )
  match command {
    Assert(expr) => inspect(manager.pretty(expr), content="(= a b)")
    _ => inspect(command, content="Assert")
  }
}

///|
test "parse_let_binding_does_not_escape" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  ignore(manager.mk_app(p_decl, []))
  ignore(parse_one_command(manager, "(assert (let ((x p)) x))"))
  expect_command_err(manager, "(assert x)", "type: undeclared symbol: x")
}

///|
test "parse_let_binding_shadows_declared_symbol" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  let q_decl = manager.declare_const("q", manager.bool_sort())
  ignore(manager.mk_app(p_decl, []))
  ignore(manager.mk_app(q_decl, []))
  let command = parse_one_command(manager, "(assert (let ((p q)) p))")
  match command {
    Assert(expr) => inspect(manager.pretty(expr), content="q")
    _ => inspect(command, content="Assert")
  }
  let after = parse_one_command(manager, "(assert p)")
  match after {
    Assert(expr) => inspect(manager.pretty(expr), content="p")
    _ => inspect(after, content="Assert")
  }
}

///|
test "parse_assert_named_bool_formula" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  ignore(manager.mk_app(p_decl, []))
  let command = parse_one_command(manager, "(assert (! p :named core-p))")
  match command {
    @cmd_context.AssertNamed(expr, name) => {
      inspect(manager.pretty(expr), content="p")
      inspect(name, content="core-p")
    }
    _ => inspect(command, content="AssertNamed")
  }
}

///|
test "parse_push_pop_check_sat_get_model" {
  let manager = @ast.AstManager::new()
  let exprs = parse_program("(push)(pop 1)(check-sat)(get-model)")
  let c0 = parse_command(manager, exprs[0])
  let c1 = parse_command(manager, exprs[1])
  let c2 = parse_command(manager, exprs[2])
  let c3 = parse_command(manager, exprs[3])
  inspect(c0, content="Push(1)")
  inspect(c1, content="Pop(1)")
  inspect(c2, content="CheckSat")
  inspect(c3, content="GetModel")
}

///|
test "parse_get_value" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  ignore(manager.mk_app(p_decl, []))
  let command = parse_one_command(manager, "(get-value (p (not p)))")
  inspect(command, content="GetValue(2)")
}

///|
test "parse_eval_extension" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  ignore(manager.mk_app(p_decl, []))
  inspect(parse_one_command(manager, "(eval p)"), content="Eval(false)")
  inspect(
    parse_one_command(manager, "(eval p :completion true)"),
    content="Eval(true)",
  )
}

///|
test "parse_check_sat_assuming" {
  let manager = @ast.AstManager::new()
  let p_decl = manager.declare_const("p", manager.bool_sort())
  ignore(manager.mk_app(p_decl, []))
  let command = parse_one_command(manager, "(check-sat-assuming ((not p)))")
  match command {
    @cmd_context.CheckSatAssuming(assumptions) => {
      inspect(assumptions.length(), content="1")
      inspect(manager.pretty(assumptions[0]), content="(not p)")
    }
    _ => inspect(command, content="CheckSatAssuming")
  }
}

///|
test "parse_get_proof" {
  let manager = @ast.AstManager::new()
  let command = parse_one_command(manager, "(get-proof)")
  inspect(command, content="GetProof")
}

///|
test "parse_get_info" {
  let manager = @ast.AstManager::new()
  inspect(
    parse_one_command(manager, "(get-info :rlimit)"),
    content="GetInfo(:rlimit)",
  )
  inspect(
    parse_one_command(manager, "(get-info :all-statistics)"),
    content="GetInfo(:all-statistics)",
  )
}

///|
test "parse_reject_quantifier" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  ignore(manager.declare_const("a", u))
  expect_command_err(
    manager, "(assert (forall ((x U)) (= x a)))", "unsupported: quantifiers are not supported in Bool+EUF milestone",
  )
}

///|
test "parse_reject_exists_quantifier" {
  let manager = @ast.AstManager::new()
  let u = manager.declare_sort("U", 0)
  ignore(manager.declare_const("a", u))
  expect_command_err(
    manager, "(assert (exists ((x U)) (= x a)))", "unsupported: quantifiers are not supported in Bool+EUF milestone",
  )
}

///|
test "parse_reject_array_sort" {
  let manager = @ast.AstManager::new()
  expect_command_err(
    manager, "(declare-const a (Array Int Int))", "unsupported: arrays are not supported in Bool+EUF milestone",
  )
}

///|
test "parse_reject_array_select" {
  let manager = @ast.AstManager::new()
  expect_command_err(
    manager, "(assert (select true true))", "unsupported: arrays are not supported in Bool+EUF milestone",
  )
}

///|
test "parse_reject_bitvec_sort" {
  let manager = @ast.AstManager::new()
  expect_command_err(
    manager, "(declare-const x (_ BitVec 8))", "unsupported: bit-vectors are not supported in Bool+EUF milestone",
  )
}

///|
test "parse_reject_bitvec_literal" {
  let manager = @ast.AstManager::new()
  expect_command_err(
    manager, "(assert #x0f)", "unsupported: bit-vectors are not supported in Bool+EUF milestone",
  )
}

///|
test "parse_reject_bitvec_indexed_operator" {
  let manager = @ast.AstManager::new()
  expect_command_err(
    manager, "(assert ((_ extract 3 0) #x0f))", "unsupported: bit-vectors are not supported in Bool+EUF milestone",
  )
}

///|
test "parse_reject_datatype_decl" {
  let manager = @ast.AstManager::new()
  expect_command_err(
    manager, "(declare-datatypes ((List 0)) (((nil))))", "unsupported: datatypes are not supported in Bool+EUF milestone",
  )
}

///|
test "parse_reject_datatype_constructor_term" {
  let manager = @ast.AstManager::new()
  expect_command_err(
    manager, "(assert (as nil List))", "unsupported: datatypes are not supported in Bool+EUF milestone",
  )
}

///|
test "parse_reject_datatype_match_term" {
  let manager = @ast.AstManager::new()
  expect_command_err(
    manager, "(assert (match true ((true true))))", "unsupported: datatypes are not supported in Bool+EUF milestone",
  )
}

///|
test "parse_reject_string_sort" {
  let manager = @ast.AstManager::new()
  expect_command_err(
    manager, "(declare-const s String)", "unsupported: strings are not supported in Bool+EUF milestone",
  )
}

///|
test "parse_reject_string_literal" {
  let manager = @ast.AstManager::new()
  expect_command_err(
    manager, "(assert \"abc\")", "unsupported: strings are not supported in Bool+EUF milestone",
  )
}

///|
test "parse_reject_seq_op" {
  let manager = @ast.AstManager::new()
  expect_command_err(
    manager, "(assert (str.++ \"a\" \"b\"))", "unsupported: strings are not supported in Bool+EUF milestone",
  )
}

///|
test "parse_reject_reserved_identifier_term" {
  let manager = @ast.AstManager::new()
  expect_command_err(
    manager, "(assert (par true))", "unsupported: reserved identifiers are not supported in Bool+EUF milestone",
  )
}

///|
test "parse_reject_arithmetic_symbol" {
  let manager = @ast.AstManager::new()
  expect_command_err(
    manager, "(assert (+ 1 2))", "unsupported: arithmetic is not supported in Bool+EUF milestone",
  )
}

///|
test "runner_reports_arith_comparison_unknown" {
  inspect(
    run_smt2("(declare-const x Int)\n(assert (< 1 x))\n(check-sat)"),
    content="unknown: unsupported-fragment(arith comparison requires theory)\n",
  )
}

///|
test "runner_reports_parse_diagnostic" {
  inspect(
    run_smt2("(assert p"),
    content="(error \"line 1, col 1: unclosed list\")",
  )
}

///|
test "runner_reports_unsupported_quantifier" {
  inspect(
    run_smt2(
      "(set-logic QF_UF)\n(declare-sort U 0)\n(declare-const a U)\n(assert (forall ((x U)) (= x a)))",
    ),
    content="unsupported: quantifiers are not supported in Bool+EUF milestone",
  )
}

///|
test "runner_exit_stops_before_later_parse_error" {
  inspect(run_smt2("(echo \"hi\")(exit)\"unterminated"), content="hi\n")
}

///|
test "runner_continues_after_unknown_command_by_default" {
  inspect(
    run_smt2("(echo \"before\")\n(mystery-cmd a b)\n(echo \"after\")"),
    content="before\nunsupported: unsupported command: mystery-cmd\nafter\n",
  )
}

///|
test "runner_continues_after_unsupported_logic_by_default" {
  inspect(
    run_smt2(
      "(set-logic QF_BOOL)\n(set-logic QF_UF)\n(declare-const p Bool)\n(assert p)\n(check-sat)",
    ),
    content="unsupported: unsupported logic: QF_BOOL\nsat\n",
  )
}

///|
test "runner_continues_after_command_parse_error_by_default" {
  inspect(
    run_smt2("(echo \"before\")\n(push nope)\n(echo \"after\")"),
    content="before\n(error \"push count must be non-negative\")\nafter\n",
  )
}

///|
test "runner_result_reports_nonzero_exit_for_command_parse_error" {
  let result = run_smt2_result(
    "(echo \"before\")\n(push nope)\n(echo \"after\")",
  )
  inspect(
    result.output(),
    content="before\n(error \"push count must be non-negative\")\nafter\n",
  )
  inspect(result.exit_code(), content="1")
}

///|
test "runner_result_keeps_zero_exit_for_unsupported_command_recovery" {
  let result = run_smt2_result(
    "(echo \"before\")\n(mystery-cmd a b)\n(echo \"after\")",
  )
  inspect(
    result.output(),
    content="before\nunsupported: unsupported command: mystery-cmd\nafter\n",
  )
  inspect(result.exit_code(), content="0")
}

///|
test "runner_result_reports_nonzero_exit_for_unclosed_list" {
  let result = run_smt2_result("(assert p")
  inspect(result.output(), content="(error \"line 1, col 1: unclosed list\")")
  inspect(result.exit_code(), content="1")
}

///|
test "runner_immediate_exit_stops_after_command_error" {
  inspect(
    run_smt2(
      "(set-option :error-behavior immediate-exit)\n(echo \"before\")\n(push nope)\n(echo \"after\")",
    ),
    content="before\n(error \"push count must be non-negative\")\n",
  )
}

///|
fn fixture_bool_sat_input() -> String {
  "(set-logic QF_UF)\n(declare-const p Bool)\n(assert p)\n(check-sat)"
}

///|
fn fixture_bool_unsat_input() -> String {
  "(set-logic QF_UF)\n(declare-const p Bool)\n(assert p)\n(assert (not p))\n(check-sat)"
}

///|
fn fixture_bool_tautology_unsat_input() -> String {
  "(set-option :auto-config true)\n(set-option :produce-models true)\n(declare-const p Bool)\n(declare-const q Bool)\n(declare-const r Bool)\n(define-fun conjecture () Bool\n  (=> (and (=> p q) (=> q r))\n      (=> p r)))\n(assert (not conjecture))\n(check-sat)"
}

///|
fn fixture_euf_sat_input() -> String {
  "(set-logic QF_UF)\n(declare-sort U 0)\n(declare-const a U)\n(declare-const b U)\n(assert (distinct a b))\n(check-sat)"
}

///|
fn fixture_euf_congruence_unsat_input() -> String {
  "(set-logic QF_UF)\n(declare-sort U 0)\n(declare-const a U)\n(declare-const b U)\n(declare-fun f (U) U)\n(assert (= a b))\n(assert (distinct (f a) (f b)))\n(check-sat)"
}

///|
fn fixture_cdclt_euf_chain_conflict_input() -> String {
  "(set-logic QF_UF)\n(declare-sort U 0)\n(declare-const a U)\n(declare-const b U)\n(declare-const c U)\n(declare-fun f (U) U)\n(assert (= a b))\n(assert (= b c))\n(assert (distinct (f a) (f c)))\n(check-sat)"
}

///|
fn fixture_mixed_conjunction_direct_unsat_input() -> String {
  "(set-logic QF_UF)\n(declare-sort U 0)\n(declare-const p Bool)\n(declare-const a U)\n(declare-const b U)\n(assert (and p (distinct a b)))\n(assert (= a b))\n(check-sat)"
}

///|
fn fixture_let_bool_unsat_input() -> String {
  "(set-logic QF_UF)\n(declare-const p Bool)\n(assert (let ((x p)) (and x (not x))))\n(check-sat)"
}

///|
fn fixture_let_euf_unsat_input() -> String {
  "(set-logic QF_UF)\n(declare-sort U 0)\n(declare-const a U)\n(declare-const b U)\n(assert (= a b))\n(assert (let ((x a) (y b)) (distinct x y)))\n(check-sat)"
}

///|
fn fixture_scope_push_pop_input() -> String {
  "(set-logic QF_UF)\n(declare-const p Bool)\n(push)\n(assert p)\n(assert (not p))\n(check-sat)\n(pop)\n(check-sat)"
}

///|
fn fixture_model_bool_const_input() -> String {
  "(set-option :produce-models true)\n(declare-const p Bool)\n(assert p)\n(check-sat)\n(get-model)"
}

///|
fn fixture_model_repeated_and_scoped_input() -> String {
  "(set-option :produce-models true)\n(declare-const p Bool)\n(assert p)\n(check-sat)\n(get-model)\n(get-model)\n(push)\n(assert (not p))\n(check-sat)\n(pop)\n(check-sat)\n(get-model)"
}

///|
fn fixture_model_euf_constants_input() -> String {
  "(set-logic QF_UF)\n(set-option :produce-models true)\n(declare-sort U 0)\n(declare-const a U)\n(declare-const b U)\n(assert (distinct a b))\n(check-sat)\n(get-model)"
}

///|
fn fixture_model_partial_unary_uf_input() -> String {
  "(set-logic QF_UF)\n(set-option :produce-models true)\n(declare-sort U 0)\n(declare-const a U)\n(declare-const b U)\n(declare-fun f (U) U)\n(assert (= (f a) b))\n(check-sat)\n(get-model)"
}

///|
fn fixture_get_value_partial_uf_completion_input() -> String {
  "(set-logic QF_UF)\n(set-option :produce-models true)\n(declare-sort U 0)\n(declare-const a U)\n(declare-const b U)\n(declare-const c U)\n(declare-fun f (U) U)\n(assert (= (f a) b))\n(check-sat)\n(get-value ((f c)))"
}

///|
fn fixture_get_value_bool_input() -> String {
  "(set-option :produce-models true)\n(declare-const p Bool)\n(assert p)\n(check-sat)\n(get-value (p (not p)))"
}

///|
fn fixture_eval_completion_input() -> String {
  "(set-option :produce-models true)\n(declare-sort U 0)\n(declare-const a U)\n(check-sat)\n(eval a)\n(eval a :completion true)"
}

///|
fn fixture_model_query_availability_input() -> String {
  "(set-option :produce-models true)\n(declare-sort U 0)\n(declare-const a U)\n(get-model)\n(get-value (a))\n(check-sat)\n(eval a)"
}

///|
fn fixture_model_query_stale_after_context_mutations_input() -> String {
  "(set-option :produce-models true)\n(declare-const p Bool)\n(check-sat)\n(push)\n(get-model)\n(check-sat)\n(pop)\n(get-value (p))\n(check-sat)\n(assert p)\n(eval p)"
}

///|
fn fixture_named_unsat_core_input() -> String {
  "(set-option :produce-unsat-cores true)\n(declare-const p Bool)\n(assert (! p :named core-p))\n(assert (not p))\n(check-sat)\n(get-unsat-core)"
}

///|
fn fixture_named_unsat_core_excludes_irrelevant_input() -> String {
  "(set-option :produce-unsat-cores true)\n(declare-const p Bool)\n(declare-const q Bool)\n(assert (! p :named core-p))\n(assert (! q :named core-q))\n(assert (not p))\n(check-sat)\n(get-unsat-core)"
}

///|
fn fixture_named_euf_unsat_core_input() -> String {
  "(set-logic QF_UF)\n(set-option :produce-unsat-cores true)\n(set-option :produce-unsat-assumptions true)\n(declare-sort U 0)\n(declare-const a U)\n(declare-const b U)\n(assert (= a b))\n(assert (! (distinct a b) :named core-diseq))\n(check-sat)\n(get-unsat-core)\n(get-unsat-assumptions)"
}

///|
fn fixture_check_sat_assuming_input() -> String {
  "(set-option :produce-unsat-assumptions true)\n(declare-const p Bool)\n(assert p)\n(check-sat-assuming ((not p)))\n(get-unsat-assumptions)\n(check-sat)"
}

///|
fn fixture_check_sat_assuming_unsat_core_input() -> String {
  "(set-option :produce-unsat-cores true)\n(declare-const p Bool)\n(assert p)\n(check-sat-assuming ((not p)))\n(get-unsat-core)"
}

///|
fn fixture_check_sat_assuming_mixed_conjunction_input() -> String {
  "(set-logic QF_UF)\n(set-option :produce-unsat-cores true)\n(set-option :produce-unsat-assumptions true)\n(declare-sort U 0)\n(declare-const p Bool)\n(declare-const a U)\n(declare-const b U)\n(assert (= a b))\n(check-sat-assuming ((and p (distinct a b))))\n(get-unsat-core)\n(get-unsat-assumptions)\n(check-sat)"
}

///|
fn fixture_get_proof_disabled_input() -> String {
  "(declare-const p Bool)\n(assert p)\n(assert (not p))\n(check-sat)\n(get-proof)"
}

///|
fn fixture_get_proof_enabled_skeleton_input() -> String {
  "(set-option :produce-proofs true)\n(declare-const p Bool)\n(assert p)\n(assert (not p))\n(check-sat)\n(get-proof)"
}

///|
fn fixture_reset_assertions_reopens_produce_proofs_input() -> String {
  "(declare-const p Bool)\n(assert p)\n(assert (not p))\n(check-sat)\n(reset-assertions)\n(check-sat)\n(set-option :produce-proofs true)\n(assert p)\n(assert (not p))\n(check-sat)\n(get-proof)"
}

///|
fn fixture_reset_reopens_logic_and_produce_proofs_input() -> String {
  "(set-logic QF_UF)\n(declare-const p Bool)\n(assert p)\n(assert (not p))\n(check-sat)\n(reset)\n(set-logic QF_UF)\n(set-option :produce-proofs true)\n(declare-const p Bool)\n(assert p)\n(assert (not p))\n(check-sat)\n(get-proof)"
}

///|
fn fixture_set_info_print_success_input() -> String {
  "(set-info :source \"z0\")\n(set-option :print-success true)\n(set-info :status unknown)\n(echo \"done\")"
}

///|
fn fixture_info_statistics_and_rlimit_input() -> String {
  "(set-option :reproducible-resource-limit 8)\n(get-info :rlimit)\n(declare-const p Bool)\n(check-sat)\n(get-info :all-statistics)\n(get-info :rlimit)"
}

///|
fn fixture_info_reason_unknown_input() -> String {
  "(get-info :reason-unknown)\n(check-sat)\n(get-info :reason-unknown)\n(declare-const p Bool)\n(assert p)\n(get-info :reason-unknown)"
}

///|
fn fixture_get_option_builtin_values_input() -> String {
  "(get-option :produce-models)\n(get-option :global-decls)\n(set-option :produce-models true)\n(set-option :global-decls true)\n(set-option :regular-output-channel \"stdout\")\n(set-option :diagnostic-output-channel \"stderr\")\n(set-option :reproducible-resource-limit 7)\n(get-option :produce-models)\n(get-option :global-decls)\n(get-option :regular-output-channel)\n(get-option :diagnostic-output-channel)\n(get-option :reproducible-resource-limit)"
}

///|
fn fixture_builtin_option_storage_input() -> String {
  "(get-option :print-warning)\n(get-option :verbosity)\n(get-option :random-seed)\n(get-option :numeral-as-real)\n(get-option :int-real-coercions)\n(get-option :error-behavior)\n(set-option :print-warning false)\n(set-option :verbosity 3)\n(set-option :random-seed 11)\n(set-option :numeral-as-real true)\n(set-option :int-real-coercions false)\n(set-option :error-behavior immediate-exit)\n(get-option :print-warning)\n(get-option :verbosity)\n(get-option :random-seed)\n(get-option :numeral-as-real)\n(get-option :int-real-coercions)\n(get-option :error-behavior)\n(get-info :error-behavior)"
}

///|
fn fixture_builtin_options_reset_preserves_input() -> String {
  "(set-option :print-success true)\n(set-option :produce-models true)\n(set-option :produce-proofs true)\n(set-option :produce-unsat-cores true)\n(set-option :produce-unsat-assumptions true)\n(set-option :regular-output-channel \"stdout\")\n(set-option :diagnostic-output-channel \"stderr\")\n(set-option :verbosity 3)\n(set-option :random-seed 11)\n(set-option :print-warning false)\n(set-option :error-behavior immediate-exit)\n(reset)\n(get-option :print-success)\n(get-option :produce-models)\n(get-option :produce-proofs)\n(get-option :produce-unsat-cores)\n(get-option :produce-unsat-assumptions)\n(get-option :regular-output-channel)\n(get-option :diagnostic-output-channel)\n(get-option :verbosity)\n(get-option :random-seed)\n(get-option :print-warning)\n(get-option :error-behavior)"
}

///|
fn fixture_set_logic_after_assertion_rejected_input() -> String {
  "(declare-const p Bool)\n(assert p)\n(set-logic QF_UF)\n(check-sat)"
}

///|
fn fixture_default_scoped_decls_input() -> String {
  "(push)\n(declare-const p Bool)\n(pop)\n(assert p)\n(check-sat)"
}

///|
fn fixture_global_decls_preserves_scoped_decl_input() -> String {
  "(set-option :global-decls true)\n(push)\n(declare-const p Bool)\n(pop)\n(assert p)\n(check-sat)\n(get-option :global-decls)"
}

///|
fn fixture_global_decls_late_set_rejected_input() -> String {
  "(push)\n(set-option :global-decls true)\n(declare-const p Bool)\n(pop)\n(assert p)"
}

///|
fn fixture_global_decls_reset_preserves_option_input() -> String {
  "(set-option :global-decls true)\n(reset)\n(get-option :global-decls)\n(push)\n(declare-const p Bool)\n(pop)\n(assert p)\n(check-sat)"
}

///|
fn fixture_unsupported_quantifier_input() -> String {
  "(set-logic QF_UF)\n(declare-sort U 0)\n(declare-const a U)\n(assert (forall ((x U)) (= x a)))\n(check-sat)"
}

///|
fn check_all_fixtures() -> Unit raise {
  inspect(run_smt2(fixture_bool_sat_input()), content="sat\n")
  inspect(run_smt2(fixture_bool_unsat_input()), content="unsat\n")
  inspect(run_smt2(fixture_bool_tautology_unsat_input()), content="unsat\n")
  inspect(run_smt2(fixture_euf_sat_input()), content="sat\n")
  inspect(run_smt2(fixture_euf_congruence_unsat_input()), content="unsat\n")
  inspect(run_smt2(fixture_cdclt_euf_chain_conflict_input()), content="unsat\n")
  inspect(
    run_smt2(fixture_mixed_conjunction_direct_unsat_input()),
    content="unsat\n",
  )
  inspect(run_smt2(fixture_let_bool_unsat_input()), content="unsat\n")
  inspect(run_smt2(fixture_let_euf_unsat_input()), content="unsat\n")
  inspect(run_smt2(fixture_scope_push_pop_input()), content="unsat\nsat\n")
  inspect(
    run_smt2(fixture_model_bool_const_input()),
    content="sat\n(\n  (define-fun p () Bool\n    true)\n)\n",
  )
  inspect(
    run_smt2(fixture_model_repeated_and_scoped_input()),
    content=(
      #|sat
      #|(
      #|  (define-fun p () Bool
      #|    true)
      #|)
      #|(
      #|  (define-fun p () Bool
      #|    true)
      #|)
      #|unsat
      #|sat
      #|(
      #|  (define-fun p () Bool
      #|    true)
      #|)
      #|
    ),
  )
  inspect(
    run_smt2(fixture_model_euf_constants_input()),
    content=(
      #|sat
      #|(
      #|  ;; universe U: @U0 @U1
      #|  (declare-fun @U0 () U)
      #|  (declare-fun @U1 () U)
      #|  ;; cardinality constraint for U
      #|  (forall ((x U)) (or (= x @U0) (= x @U1)))
      #|  (define-fun a () U
      #|    @U0)
      #|  (define-fun b () U
      #|    @U1)
      #|)
      #|
    ),
  )
  inspect(
    run_smt2(fixture_model_partial_unary_uf_input()),
    content=(
      #|sat
      #|(
      #|  ;; universe U: @U0 @U1
      #|  (declare-fun @U0 () U)
      #|  (declare-fun @U1 () U)
      #|  ;; cardinality constraint for U
      #|  (forall ((x U)) (or (= x @U0) (= x @U1)))
      #|  (define-fun a () U
      #|    @U0)
      #|  (define-fun b () U
      #|    @U1)
      #|  (define-fun f ((x0 U)) U
      #|    (ite (= x0 @U0)
      #|      @U1
      #|      #unspecified))
      #|)
      #|
    ),
  )
  inspect(
    run_smt2(fixture_get_value_bool_input()),
    content="sat\n((p true) ((not p) false))\n",
  )
  inspect(
    run_smt2(fixture_get_value_partial_uf_completion_input()),
    content="sat\n(((f c) @U3))\n",
  )
  inspect(
    run_smt2(fixture_eval_completion_input()),
    content="sat\nerror: eval is not available: unknown(model-eval-failed)\n@U0\n",
  )
  inspect(
    run_smt2(fixture_model_query_availability_input()),
    content=(
      #|error: model is not available: no-current-result
      #|error: value is not available: no-current-result
      #|sat
      #|error: eval is not available: unknown(model-eval-failed)
      #|
    ),
  )
  inspect(
    run_smt2(fixture_model_query_stale_after_context_mutations_input()),
    content=(
      #|sat
      #|error: model is not available: stale
      #|sat
      #|error: value is not available: stale
      #|sat
      #|error: eval is not available: stale
      #|
    ),
  )
  inspect(run_smt2(fixture_named_unsat_core_input()), content="unsat\ncore-p\n")
  inspect(
    run_smt2(fixture_named_unsat_core_excludes_irrelevant_input()),
    content="unsat\ncore-p\n",
  )
  inspect(
    run_smt2(fixture_named_euf_unsat_core_input()),
    content="unsat\ncore-diseq\ncore-diseq\n",
  )
  inspect(
    run_smt2(fixture_check_sat_assuming_input()),
    content="unsat\n(not p)\nsat\n",
  )
  inspect(
    run_smt2(fixture_check_sat_assuming_unsat_core_input()),
    content="unsat\n(not p)\n",
  )
  inspect(
    run_smt2(fixture_check_sat_assuming_mixed_conjunction_input()),
    content="unsat\n(and p (distinct a b))\n(and p (distinct a b))\nsat\n",
  )
  inspect(
    run_smt2(fixture_get_proof_disabled_input()),
    content="unsat\nerror: proof production is disabled\n",
  )
  inspect(
    run_smt2(fixture_get_proof_enabled_skeleton_input()),
    content="unsat\nproof#0(ast)\n",
  )
  inspect(
    run_smt2(fixture_reset_assertions_reopens_produce_proofs_input()),
    content="unsat\nsat\nunsat\nproof#0(ast)\n",
  )
  inspect(
    run_smt2(fixture_reset_reopens_logic_and_produce_proofs_input()),
    content="unsat\nunsat\nproof#0(ast)\n",
  )
  inspect(
    run_smt2(fixture_set_info_print_success_input()),
    content="success\nsuccess\ndone\n",
  )
  inspect(
    run_smt2(fixture_info_statistics_and_rlimit_input()),
    content="(:rlimit 1)\nsat\n(:all-statistics solver.checks)\n(:rlimit 5)\n",
  )
  inspect(
    run_smt2(fixture_get_option_builtin_values_input()),
    content="false\nfalse\ntrue\ntrue\n\"stdout\"\n\"stderr\"\n7\n",
  )
  inspect(
    run_smt2(fixture_builtin_option_storage_input()),
    content=(
      #|true
      #|0
      #|0
      #|false
      #|true
      #|continued-execution
      #|false
      #|3
      #|11
      #|true
      #|false
      #|immediate-exit
      #|(:error-behavior immediate-exit)
      #|
    ),
  )
  inspect(
    run_smt2(fixture_builtin_options_reset_preserves_input()),
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
  inspect(
    run_smt2(fixture_set_logic_after_assertion_rejected_input()),
    content="solver: cannot set logic after assertions have been added",
  )
  inspect(
    run_smt2(fixture_global_decls_preserves_scoped_decl_input()),
    content="sat\ntrue\n",
  )
  inspect(
    run_smt2(fixture_global_decls_reset_preserves_option_input()),
    content="true\nsat\n",
  )
  inspect(
    run_smt2(fixture_unsupported_quantifier_input()),
    content="unsupported: quantifiers are not supported in Bool+EUF milestone",
  )
}

///|
test "fixture" {
  check_all_fixtures()
}

///|
test "fixture_bool_sat" {
  inspect(run_smt2(fixture_bool_sat_input()), content="sat\n")
}

///|
test "fixture_bool_unsat" {
  inspect(run_smt2(fixture_bool_unsat_input()), content="unsat\n")
}

///|
test "fixture_bool_tautology_unsat" {
  inspect(run_smt2(fixture_bool_tautology_unsat_input()), content="unsat\n")
}

///|
test "fixture_euf_sat" {
  inspect(run_smt2(fixture_euf_sat_input()), content="sat\n")
}

///|
test "fixture_euf_congruence_unsat" {
  inspect(run_smt2(fixture_euf_congruence_unsat_input()), content="unsat\n")
}

///|
test "fixture_cdclt_euf_chain_conflict" {
  inspect(run_smt2(fixture_cdclt_euf_chain_conflict_input()), content="unsat\n")
}

///|
test "fixture_mixed_conjunction_direct_unsat" {
  inspect(
    run_smt2(fixture_mixed_conjunction_direct_unsat_input()),
    content="unsat\n",
  )
}

///|
test "fixture_let_bool_unsat" {
  inspect(run_smt2(fixture_let_bool_unsat_input()), content="unsat\n")
}

///|
test "fixture_let_euf_unsat" {
  inspect(run_smt2(fixture_let_euf_unsat_input()), content="unsat\n")
}

///|
test "fixture_scope_push_pop" {
  inspect(run_smt2(fixture_scope_push_pop_input()), content="unsat\nsat\n")
}

///|
test "fixture_model_bool_const" {
  inspect(
    run_smt2(fixture_model_bool_const_input()),
    content="sat\n(\n  (define-fun p () Bool\n    true)\n)\n",
  )
}

///|
test "fixture_model_repeated_and_scoped" {
  inspect(
    run_smt2(fixture_model_repeated_and_scoped_input()),
    content=(
      #|sat
      #|(
      #|  (define-fun p () Bool
      #|    true)
      #|)
      #|(
      #|  (define-fun p () Bool
      #|    true)
      #|)
      #|unsat
      #|sat
      #|(
      #|  (define-fun p () Bool
      #|    true)
      #|)
      #|
    ),
  )
}

///|
test "fixture_model_euf_constants" {
  inspect(
    run_smt2(fixture_model_euf_constants_input()),
    content=(
      #|sat
      #|(
      #|  ;; universe U: @U0 @U1
      #|  (declare-fun @U0 () U)
      #|  (declare-fun @U1 () U)
      #|  ;; cardinality constraint for U
      #|  (forall ((x U)) (or (= x @U0) (= x @U1)))
      #|  (define-fun a () U
      #|    @U0)
      #|  (define-fun b () U
      #|    @U1)
      #|)
      #|
    ),
  )
}

///|
test "fixture_model_partial_unary_uf" {
  inspect(
    run_smt2(fixture_model_partial_unary_uf_input()),
    content=(
      #|sat
      #|(
      #|  ;; universe U: @U0 @U1
      #|  (declare-fun @U0 () U)
      #|  (declare-fun @U1 () U)
      #|  ;; cardinality constraint for U
      #|  (forall ((x U)) (or (= x @U0) (= x @U1)))
      #|  (define-fun a () U
      #|    @U0)
      #|  (define-fun b () U
      #|    @U1)
      #|  (define-fun f ((x0 U)) U
      #|    (ite (= x0 @U0)
      #|      @U1
      #|      #unspecified))
      #|)
      #|
    ),
  )
}

///|
test "fixture_get_value_bool" {
  inspect(
    run_smt2(fixture_get_value_bool_input()),
    content="sat\n((p true) ((not p) false))\n",
  )
}

///|
test "fixture_get_value_partial_uf_completion" {
  inspect(
    run_smt2(fixture_get_value_partial_uf_completion_input()),
    content="sat\n(((f c) @U3))\n",
  )
}

///|
test "fixture_eval_completion" {
  inspect(
    run_smt2(fixture_eval_completion_input()),
    content="sat\nerror: eval is not available: unknown(model-eval-failed)\n@U0\n",
  )
}

///|
test "fixture_model_query_availability" {
  inspect(
    run_smt2(fixture_model_query_availability_input()),
    content=(
      #|error: model is not available: no-current-result
      #|error: value is not available: no-current-result
      #|sat
      #|error: eval is not available: unknown(model-eval-failed)
      #|
    ),
  )
}

///|
test "fixture_model_query_stale_after_context_mutations" {
  inspect(
    run_smt2(fixture_model_query_stale_after_context_mutations_input()),
    content=(
      #|sat
      #|error: model is not available: stale
      #|sat
      #|error: value is not available: stale
      #|sat
      #|error: eval is not available: stale
      #|
    ),
  )
}

///|
test "fixture_named_unsat_core" {
  inspect(run_smt2(fixture_named_unsat_core_input()), content="unsat\ncore-p\n")
}

///|
test "fixture_named_unsat_core_excludes_irrelevant" {
  inspect(
    run_smt2(fixture_named_unsat_core_excludes_irrelevant_input()),
    content="unsat\ncore-p\n",
  )
}

///|
test "fixture_named_euf_unsat_core" {
  inspect(
    run_smt2(fixture_named_euf_unsat_core_input()),
    content="unsat\ncore-diseq\ncore-diseq\n",
  )
}

///|
test "fixture_check_sat_assuming" {
  inspect(
    run_smt2(fixture_check_sat_assuming_input()),
    content="unsat\n(not p)\nsat\n",
  )
}

///|
test "fixture_check_sat_assuming_unsat_core" {
  inspect(
    run_smt2(fixture_check_sat_assuming_unsat_core_input()),
    content="unsat\n(not p)\n",
  )
}

///|
test "fixture_check_sat_assuming_mixed_conjunction" {
  inspect(
    run_smt2(fixture_check_sat_assuming_mixed_conjunction_input()),
    content="unsat\n(and p (distinct a b))\n(and p (distinct a b))\nsat\n",
  )
}

///|
test "fixture_get_proof_disabled" {
  inspect(
    run_smt2(fixture_get_proof_disabled_input()),
    content="unsat\nerror: proof production is disabled\n",
  )
}

///|
test "fixture_get_proof_enabled_skeleton" {
  inspect(
    run_smt2(fixture_get_proof_enabled_skeleton_input()),
    content="unsat\nproof#0(ast)\n",
  )
}

///|
test "fixture_reset_assertions_reopens_produce_proofs" {
  inspect(
    run_smt2(fixture_reset_assertions_reopens_produce_proofs_input()),
    content="unsat\nsat\nunsat\nproof#0(ast)\n",
  )
}

///|
test "fixture_reset_reopens_logic_and_produce_proofs" {
  inspect(
    run_smt2(fixture_reset_reopens_logic_and_produce_proofs_input()),
    content="unsat\nunsat\nproof#0(ast)\n",
  )
}

///|
test "fixture_set_info_print_success" {
  inspect(
    run_smt2(fixture_set_info_print_success_input()),
    content="success\nsuccess\ndone\n",
  )
}

///|
test "fixture_info_statistics_and_rlimit" {
  inspect(
    run_smt2(fixture_info_statistics_and_rlimit_input()),
    content="(:rlimit 1)\nsat\n(:all-statistics solver.checks)\n(:rlimit 5)\n",
  )
}

///|
test "fixture_info_reason_unknown" {
  inspect(
    run_smt2(fixture_info_reason_unknown_input()),
    content="(:reason-unknown no-current-result)\nsat\n(:reason-unknown no-current-result)\n(:reason-unknown stale)\n",
  )
}

///|
test "fixture_get_option_builtin_values" {
  inspect(
    run_smt2(fixture_get_option_builtin_values_input()),
    content="false\nfalse\ntrue\ntrue\n\"stdout\"\n\"stderr\"\n7\n",
  )
}

///|
test "fixture_builtin_option_storage" {
  inspect(
    run_smt2(fixture_builtin_option_storage_input()),
    content=(
      #|true
      #|0
      #|0
      #|false
      #|true
      #|continued-execution
      #|false
      #|3
      #|11
      #|true
      #|false
      #|immediate-exit
      #|(:error-behavior immediate-exit)
      #|
    ),
  )
}

///|
test "fixture_builtin_options_reset_preserves" {
  inspect(
    run_smt2(fixture_builtin_options_reset_preserves_input()),
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
test "fixture_set_logic_after_assertion_rejected" {
  inspect(
    run_smt2(fixture_set_logic_after_assertion_rejected_input()),
    content="solver: cannot set logic after assertions have been added",
  )
}

///|
test "fixture_default_scoped_decls" {
  inspect(
    run_smt2(fixture_default_scoped_decls_input()),
    content="type: undeclared symbol: p",
  )
}

///|
test "fixture_global_decls_preserves_scoped_decl" {
  inspect(
    run_smt2(fixture_global_decls_preserves_scoped_decl_input()),
    content="sat\ntrue\n",
  )
}

///|
test "fixture_global_decls_late_set_rejected" {
  inspect(
    run_smt2(fixture_global_decls_late_set_rejected_input()),
    content="solver: cannot set :global-decls while scopes are active",
  )
}

///|
test "fixture_global_decls_reset_preserves_option" {
  inspect(
    run_smt2(fixture_global_decls_reset_preserves_option_input()),
    content="true\nsat\n",
  )
}

///|
test "fixture_unsupported_quantifier" {
  inspect(
    run_smt2(fixture_unsupported_quantifier_input()),
    content="unsupported: quantifiers are not supported in Bool+EUF milestone",
  )
}
