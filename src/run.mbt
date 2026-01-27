///|
pub fn run_smt(testcase : String) -> Unit raise {
  let source = @fs.read_file_to_string("./smt2/\{testcase}.smt2")
    |> @parser.parse_smtlib()
    |> @runner.parse_script()
  let expected_output = @fs.read_file_to_string(
    "./smt2/\{testcase}.expected.out",
  ).trim()
  let runner = @runner.Runner::new()
  let out = runner.execute(source).join("\n")[:]
  assert_eq(out, expected_output)
}

///|
test "2557" {
  run_smt("2557")
}

///|
test "t130" {
  run_smt("t130")
}

///|
test "3103" {
  run_smt("3103")
}

///|
test "t111" {
  run_smt("t111")
}

///|
test "fp-rem-5" {
  run_smt("fp-rem-5")
}

///|
test "mul" {
  run_smt("mul")
}
