///|
test "shell_help_text_contains_usage" {
  inspect(usage(), content="Usage: z0 <file.smt2>")
}

///|
test "shell_rejects_missing_file_argument" {
  inspect(parse_args([]), content="RejectArgs")
}

///|
test "shell_action_help_reports_zero_exit" {
  let result = run_action(ShowHelp)
  inspect(result.stdout, content="Usage: z0 <file.smt2>\n")
  inspect(result.stderr, content="")
  inspect(result.exit_code, content="0")
}

///|
test "shell_action_reject_args_reports_nonzero_exit" {
  let result = run_action(RejectArgs)
  inspect(result.stdout, content="Usage: z0 <file.smt2>\n")
  inspect(result.stderr, content="")
  inspect(result.exit_code, content="1")
}

///|
test "shell_action_run_file_reports_runner_parse_error_exit" {
  let result = run_action(
    RunFile("smt2/z3_arch_error_recovery_parse_continued.smt2"),
  )
  inspect(
    result.stdout,
    content="before\n(error \"push count must be non-negative\")\nafter\n",
  )
  inspect(result.stderr, content="")
  inspect(result.exit_code, content="1")
}

///|
test "shell_formats_solver_output" {
  let input = "(set-logic QF_UF)\n(declare-const p Bool)\n(assert p)\n(check-sat)"
  inspect(run_input(input), content="sat\n")
}

///|
test "shell_interactive_input_matches_file_output" {
  let input = "(set-logic QF_UF)\n(declare-const p Bool)\n(assert p)\n(check-sat)"
  inspect(run_interactive_input(input), content=run_input(input))
}
