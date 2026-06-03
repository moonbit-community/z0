///|
struct Z3ArchShellFixture {
  id : String
  input_file : String
  expected_stdout : String
  expected_stderr : String
  expected_exit_code : String
  runner_modes : String
  command_kind : String
  support_status : String
  status_category : String
  z3_expected : String
  z3_diff_reason : String
  normalization : String
}

///|
fn z3_arch_shell_fixture_from_manifest_line(
  line : String,
) -> Z3ArchShellFixture {
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
    command_kind: columns[7],
    support_status: columns[8],
    status_category: columns[11],
    z3_expected: columns[14],
    z3_diff_reason: columns[15],
    normalization: columns[18],
  }
}

///|
fn z3_arch_shell_fixtures_from_manifest(
  manifest : String,
) -> Array[Z3ArchShellFixture] {
  let fixtures : Array[Z3ArchShellFixture] = []
  for raw_line in manifest.split("\n") {
    let line = raw_line.trim().to_owned()
    if !line.is_empty() && !line.contains("id|input_file") {
      let fixture = z3_arch_shell_fixture_from_manifest_line(line)
      if fixture.runner_modes.contains("file-shell") {
        fixtures.push(fixture)
      }
    }
  }
  fixtures
}

///|
fn z3_arch_all_fixtures_from_manifest(
  manifest : String,
) -> Array[Z3ArchShellFixture] {
  let fixtures : Array[Z3ArchShellFixture] = []
  for raw_line in manifest.split("\n") {
    let line = raw_line.trim().to_owned()
    if !line.is_empty() && !line.contains("id|input_file") {
      fixtures.push(z3_arch_shell_fixture_from_manifest_line(line))
    }
  }
  fixtures
}

///|
fn z3_arch_validate_fixture_paths(fixture : Z3ArchShellFixture) -> Unit raise {
  if fixture.input_file != "smt2/\{fixture.id}.smt2" {
    fail("manifest input path does not match fixture id: \{fixture.id}")
  }
  if fixture.expected_stdout != "smt2/\{fixture.id}.expected.out" {
    fail(
      "manifest expected output path does not match fixture id: \{fixture.id}",
    )
  }
  if fixture.expected_stderr != "" &&
    fixture.expected_stderr != "smt2/\{fixture.id}.expected.err" {
    fail(
      "manifest expected stderr path does not match fixture id: \{fixture.id}",
    )
  }
}

///|
fn z3_arch_validate_shell_fixture(fixture : Z3ArchShellFixture) -> Unit raise {
  if !fixture.runner_modes.contains("interactive-shell") {
    fail("fixture does not enable interactive-shell mode: \{fixture.id}")
  }
  if fixture.expected_exit_code != "0" && fixture.expected_exit_code != "1" {
    fail("file-shell seed expects exit code 0 or 1: \{fixture.id}")
  }
  if fixture.normalization != "exact" {
    fail("file-shell seed only supports exact normalization: \{fixture.id}")
  }
  z3_arch_validate_fixture_paths(fixture)
}

///|
fn z3_arch_read_expected_stderr(fixture : Z3ArchShellFixture) -> String raise {
  if fixture.expected_stderr == "" {
    ""
  } else {
    read_input_file(fixture.expected_stderr)
  }
}

///|
fn z3_arch_theory_parity_family(family : String) -> Bool {
  family == "array" ||
  family == "bv" ||
  family == "datatype" ||
  family == "seq" ||
  family == "quantifier"
}

///|
fn z3_arch_array_contains(values : Array[String], value : String) -> Bool {
  for item in values {
    if item == value {
      return true
    }
  }
  false
}

///|
fn z3_arch_push_unique(values : Array[String], value : String) -> Unit {
  if !z3_arch_array_contains(values, value) {
    values.push(value)
  }
}

///|
fn z3_arch_theory_parity_ids_from_doc(doc : String) -> Array[String] {
  let ids : Array[String] = []
  for token in doc.split("`") {
    let value = token.trim().to_owned()
    if value.has_prefix("z3_arch_") {
      z3_arch_push_unique(ids, value)
    }
  }
  ids
}

///|
fn z3_arch_theory_parity_ids_from_manifest(manifest : String) -> Array[String] {
  let ids : Array[String] = []
  for raw_line in manifest.split("\n") {
    let line = raw_line.trim().to_owned()
    if !line.is_empty() && !line.contains("id|input_file") {
      let columns = line
        .split("|")
        .map(part => part.trim().to_owned())
        .to_array()
      if columns.length() != 19 {
        abort("expected 19 manifest columns, got \{columns.length()}: \{line}")
      }
      if columns[8] == "explicit-unsupported" &&
        z3_arch_theory_parity_family(columns[9]) {
        ids.push(columns[0])
      }
    }
  }
  ids
}

///|
test "z3_arch_followup_theory_parity_doc_matches_manifest_ids" {
  let manifest = read_input_file("smt2/z3_arch_manifest.txt")
  let doc = read_input_file("docs/followup-theory-parity.md")
  let ids = z3_arch_theory_parity_ids_from_manifest(manifest)
  let doc_ids = z3_arch_theory_parity_ids_from_doc(doc)
  let planned_ids = [
    "z3_arch_unknown_unsupported", "z3_arch_unsupported_array_sort", "z3_arch_unsupported_array_select_store",
    "z3_arch_unsupported_bv_sort", "z3_arch_unsupported_bv_literal", "z3_arch_unsupported_bv_indexed_op",
    "z3_arch_unsupported_datatype_decl", "z3_arch_unsupported_datatype_constructor",
    "z3_arch_unsupported_datatype_match", "z3_arch_unsupported_string_sort", "z3_arch_unsupported_string_literal",
    "z3_arch_unsupported_seq_op", "z3_arch_unsupported_exists",
  ]
  inspect(ids.length(), content="13")
  inspect(doc_ids.length(), content="13")
  for id in planned_ids {
    if !z3_arch_array_contains(ids, id) {
      fail("manifest is missing follow-up theory fixture id: \{id}")
    }
    if !z3_arch_array_contains(doc_ids, id) {
      fail("follow-up theory parity doc is missing fixture id: \{id}")
    }
  }
  for id in ids {
    if !z3_arch_array_contains(doc_ids, id) {
      fail("manifest theory fixture is not documented: \{id}")
    }
  }
  for id in doc_ids {
    if !z3_arch_array_contains(ids, id) {
      fail(
        "follow-up theory parity doc fixture is missing from manifest: \{id}",
      )
    }
  }
}

///|
test "z3_arch_smoke_suite_doc_matches_manifest_rows" {
  let manifest = read_input_file("smt2/z3_arch_manifest.txt")
  let doc = read_input_file("docs/z3-arch-smoke-suite.md")
  let fixtures = z3_arch_all_fixtures_from_manifest(manifest)
  inspect(fixtures.length(), content="91")
  for fixture in fixtures {
    let row = "| `\{fixture.id}` | `\{fixture.expected_stdout}` | `\{fixture.runner_modes}` | `\{fixture.command_kind}` | `\{fixture.support_status}` | `\{fixture.status_category}` | `\{fixture.z3_expected}` | `\{fixture.z3_diff_reason}` |"
    if !doc.contains(row) {
      fail("smoke suite doc is missing manifest row: \{fixture.id}")
    }
  }
}

///|
test "z3_arch_manifest_disk_paths_exist_for_all_rows" {
  let manifest = read_input_file("smt2/z3_arch_manifest.txt")
  let fixtures = z3_arch_all_fixtures_from_manifest(manifest)
  inspect(fixtures.length(), content="91")
  for fixture in fixtures {
    z3_arch_validate_fixture_paths(fixture)
    ignore(read_input_file(fixture.input_file))
    ignore(read_input_file(fixture.expected_stdout))
    if fixture.expected_stderr != "" {
      ignore(read_input_file(fixture.expected_stderr))
    }
  }
}

///|
test "z3_arch_file_and_interactive_shell_fixtures_match_disk_expected_output" {
  let manifest = read_input_file("smt2/z3_arch_manifest.txt")
  let fixtures = z3_arch_shell_fixtures_from_manifest(manifest)
  assert_true(fixtures.length() > 0)
  inspect(fixtures.length(), content="75")
  for fixture in fixtures {
    z3_arch_validate_shell_fixture(fixture)
    let input = read_input_file(fixture.input_file)
    let expected = read_input_file(fixture.expected_stdout)
    let expected_stderr = z3_arch_read_expected_stderr(fixture)
    let file_output = run_input(input)
    let interactive_output = run_interactive_input(input)
    let shell_result = run_action(RunFile(fixture.input_file))
    inspect(file_output, content=normalize_shell_stream(expected))
    inspect(interactive_output, content=file_output)
    inspect(shell_result.stdout, content=file_output)
    inspect(
      shell_result.stderr,
      content=normalize_shell_stream(expected_stderr),
    )
    inspect("\{shell_result.exit_code}", content=fixture.expected_exit_code)
  }
}
