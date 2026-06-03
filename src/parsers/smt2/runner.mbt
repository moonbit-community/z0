///|
fn runner_parse_message_body(message : String) -> String {
  if message.has_prefix("parse: ") {
    let parts = message.split("parse: ").map(part => part.to_owned()).to_array()
    if parts.length() >= 2 {
      parts[1]
    } else {
      ""
    }
  } else {
    message
  }
}

///|
fn smt2_quote_runner_error_string(value : String) -> String {
  let builder = StringBuilder::new()
  builder.write_char('"')
  for c in value {
    if c == '"' {
      builder.write_string("\\\"")
    } else if c == '\\' {
      builder.write_string("\\\\")
    } else {
      builder.write_char(c)
    }
  }
  builder.write_char('"')
  builder.to_string()
}

///|
fn runner_error_display_text(message : String) -> String {
  if message.has_prefix("parse:") || message.has_prefix("line ") {
    "(error \{smt2_quote_runner_error_string(runner_parse_message_body(message))})"
  } else {
    message
  }
}

///|
fn output_or_error(
  context : @cmd_context.CommandContext,
  message : String,
) -> String {
  let display = runner_error_display_text(message)
  let output = context.output()
  if output.is_empty() {
    display
  } else {
    output + display + "\n"
  }
}

///|
pub struct Smt2RunResult {
  priv output : String
  priv stderr : String
  priv exit_code : Int
}

///|
pub fn Smt2RunResult::output(self : Smt2RunResult) -> String {
  self.output
}

///|
pub fn Smt2RunResult::stderr(self : Smt2RunResult) -> String {
  self.stderr
}

///|
pub fn Smt2RunResult::exit_code(self : Smt2RunResult) -> Int {
  self.exit_code
}

///|
fn smt2_run_result(
  output : String,
  stderr : String,
  exit_code : Int,
) -> Smt2RunResult {
  { output, stderr, exit_code }
}

///|
fn exit_code_for_error(message : String) -> Int {
  if message.has_prefix("parse:") || message.has_prefix("line ") {
    1
  } else {
    0
  }
}

///|
fn combine_exit_code(exit_code : Int, message : String) -> Int {
  if exit_code != 0 || exit_code_for_error(message) != 0 {
    1
  } else {
    0
  }
}

///|
fn output_or_error_result(
  context : @cmd_context.CommandContext,
  message : String,
  exit_code : Int,
) -> Smt2RunResult {
  smt2_run_result(
    output_or_error(context, message),
    context.stderr_output(),
    exit_code,
  )
}

///|
fn can_continue_after_error(message : String) -> Bool {
  message.has_prefix("parse:") ||
  message.has_prefix("unsupported: unsupported command:") ||
  message.has_prefix("unsupported: unsupported logic:")
}

///|
pub fn run_smt2_result_with_factory(
  input : String,
  factory : @solver.SolverFactory,
) -> Smt2RunResult {
  let context = @cmd_context.CommandContext::new(factory)
  let mut cursor = SExprCursor::new(input)
  let mut pending_error : String? = None
  let mut exit_code = 0
  while !context.exited() {
    let next_expr = parse_next(cursor) catch {
      err => {
        match pending_error {
          Some(message) => {
            exit_code = combine_exit_code(exit_code, message)
            context.append_runner_message(message)
          }
          None => ()
        }
        let message = err.to_string()
        return output_or_error_result(
          context,
          message,
          combine_exit_code(exit_code, message),
        )
      }
    }
    match next_expr {
      End(_) =>
        match pending_error {
          Some(message) =>
            return output_or_error_result(
              context,
              message,
              combine_exit_code(exit_code, message),
            )
          None =>
            return smt2_run_result(
              context.output(),
              context.stderr_output(),
              exit_code,
            )
        }
      Next(expr, next) => {
        cursor = next
        match pending_error {
          Some(message) => {
            exit_code = combine_exit_code(exit_code, message)
            context.append_runner_message(message)
            pending_error = None
          }
          None => ()
        }
        let command_opt : @cmd_context.Command? = Some(
          parse_command(context.manager(), expr),
        ) catch {
          err => {
            let message = err.to_string()
            if context.error_behavior() == "immediate-exit" ||
              !can_continue_after_error(message) {
              return output_or_error_result(
                context,
                message,
                combine_exit_code(exit_code, message),
              )
            } else {
              pending_error = Some(message)
              None
            }
          }
        }
        match command_opt {
          Some(command) => {
            let executed = try {
              context.execute(command)
              true
            } catch {
              err => {
                let message = err.to_string()
                if context.error_behavior() == "immediate-exit" ||
                  !can_continue_after_error(message) {
                  return output_or_error_result(
                    context,
                    message,
                    combine_exit_code(exit_code, message),
                  )
                } else {
                  pending_error = Some(message)
                  false
                }
              }
            }
            ignore(executed)
          }
          None => ()
        }
      }
    }
  }
  match pending_error {
    Some(message) =>
      output_or_error_result(
        context,
        message,
        combine_exit_code(exit_code, message),
      )
    None =>
      smt2_run_result(context.output(), context.stderr_output(), exit_code)
  }
}

///|
pub fn run_smt2_with_factory(
  input : String,
  factory : @solver.SolverFactory,
) -> String {
  run_smt2_result_with_factory(input, factory).output()
}
