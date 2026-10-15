///|
pub(all) enum ShellAction {
  ShowHelp
  RunFile(String)
  RejectArgs
} derive(Eq)

///|
pub impl Show for ShellAction with fn output(self, logger) {
  match self {
    ShowHelp => logger.write_string("ShowHelp")
    RunFile(path) => logger.write_string("RunFile(\{path})")
    RejectArgs => logger.write_string("RejectArgs")
  }
}

///|
pub fn usage() -> String {
  "Usage: z0 <file.smt2>"
}

///|
pub fn parse_args(args : Array[String]) -> ShellAction {
  match args {
    ["--help"] | ["-h"] => ShowHelp
    [path] => RunFile(path)
    _ => RejectArgs
  }
}

///|
priv struct ShellResult {
  stdout : String
  stderr : String
  exit_code : Int32
}

///|
pub fn normalize_output(output : String) -> String {
  output.trim_end(chars="\n").to_owned() + "\n"
}

///|
fn normalize_shell_stream(output : String) -> String {
  if output.is_empty() || output.trim(chars="\n").is_empty() {
    ""
  } else {
    normalize_output(output)
  }
}

///|
pub fn run_input(input : String) -> String {
  normalize_shell_stream(
    @smt2.run_smt2_with_factory(input, @assembly.solver_factory()),
  )
}

///|
pub fn run_interactive_input(input : String) -> String {
  run_input(input)
}

///|
pub async fn read_input_file(path : String) -> String {
  @fs.read_file(path).text() catch {
    err => raise @io_error.IoError(Show::to_string(err))
  }
}

///|
fn shell_result(
  stdout : String,
  stderr : String,
  exit_code : Int32,
) -> ShellResult {
  { stdout, stderr, exit_code, }
}

///|
async fn run_action(action : ShellAction) -> ShellResult {
  match action {
    ShowHelp => shell_result(usage() + "\n", "", 0)
    RejectArgs => shell_result(usage() + "\n", "", 1)
    RunFile(path) => {
      let input = read_input_file(path) catch {
        err => return shell_result(Show::to_string(err) + "\n", "", 1)
      }
      let result = @smt2.run_smt2_result_with_factory(
        input,
        @assembly.solver_factory(),
      )
      shell_result(
        normalize_shell_stream(result.output()),
        normalize_shell_stream(result.stderr()),
        result.exit_code(),
      )
    }
  }
}

///|
fn user_args() -> Array[String] {
  let args = @env.args()
  let parsed : Array[String] = []
  for i in 1..<args.length() {
    parsed.push(args[i])
  }
  parsed
}

///|
fn print_shell_result(result : ShellResult) -> Unit {
  if !result.stdout.is_empty() {
    println(result.stdout.trim_end(chars="\n"))
  }
  if !result.stderr.is_empty() {
    println(result.stderr.trim_end(chars="\n"))
  }
}

///|
async fn main {
  let result = run_action(parse_args(user_args()))
  print_shell_result(result)
  if result.exit_code != 0 {
    exit(result.exit_code)
  }
}
