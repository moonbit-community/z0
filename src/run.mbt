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
