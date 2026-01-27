///|
pub struct Runner {
  solver : @solver.Solver
  mut last_result : @solver.CheckSatResult?
}

///|
pub fn Runner::new() -> Runner {
  { solver: @solver.Solver::new(), last_result: None }
}

///|
fn result_to_string(res : @solver.CheckSatResult) -> String {
  match res {
    @solver.CheckSatResult::Sat(_) => "sat"
    @solver.CheckSatResult::Unsat => "unsat"
    @solver.CheckSatResult::Unknown(_) => "unknown"
  }
}

///|
pub fn Runner::execute(
  self : Runner,
  script : Script,
) -> Array[StringView] raise Smt2Error {
  let output : Array[StringView] = []
  for cmd in script.commands {
    match cmd {
      Command::SetLogic(_) => ()
      Command::SetOption(_, _) => ()
      Command::SetInfo(_, _) => ()
      Command::DeclareSort(_, _) => ()
      Command::DefineSort(_, _, _) => ()
      Command::DeclareConst(name, sort) => self.solver.declare_const(name, sort)
      Command::DeclareFun(_, _, _) => ()
      Command::DefineFun(_, _, _, _) => ()
      Command::Assert(term) => self.solver.assert_term(term)
      Command::Simplify(expr, opts) => {
        let simplified = simplify_with_options(expr, opts)
        output.push(sexpr_to_smt2_pretty(simplified))
      }
      Command::Push(n) =>
        for _ in 0..<n {
          self.solver.push()
        }
      Command::Pop(n) =>
        match self.solver.pop(n) {
          Ok(_) => ()
          Err(@solver.SolverError::ScopeUnderflow(expected~, available~)) =>
            raise Smt2Error::ScopeUnderflow(expected~, available~)
          Err(@solver.SolverError::Unsupported(msg)) =>
            raise Smt2Error::Unsupported(msg)
          Err(@solver.SolverError::InvalidAssertion(msg)) =>
            raise Smt2Error::Malformed(msg)
        }
      Command::CheckSat => {
        let res = self.solver.check_sat()
        self.last_result = Some(res)
        output.push(result_to_string(res))
      }
      Command::CheckSatUsing(_) => {
        let res = self.solver.check_sat()
        self.last_result = Some(res)
        output.push(result_to_string(res))
      }
      Command::GetValue(terms) =>
        match self.last_result {
          Some(@solver.CheckSatResult::Sat(model)) => {
            let pairs = terms.map(term => {
              let value = eval_term(term, model)
              "(\{@solver.term_to_smt2(term)} \{@solver.term_to_smt2(value)})"
            })
            let joined = pairs.join(" ")
            output.push("(\{joined})")
          }
          Some(@solver.CheckSatResult::Unsat) =>
            output.push("(error \"model is not available\")")
          Some(@solver.CheckSatResult::Unknown(_)) =>
            output.push("(error \"model is not available\")")
          None => output.push("(error \"model is not available\")")
        }
      Command::GetModel =>
        match self.last_result {
          Some(@solver.CheckSatResult::Sat(model)) =>
            output.push(model.to_smt2())
          Some(@solver.CheckSatResult::Unsat) =>
            output.push("(error \"model is not available\")")
          Some(@solver.CheckSatResult::Unknown(_)) =>
            output.push("(error \"model is not available\")")
          None => output.push("(error \"model is not available\")")
        }
      Command::Exit => break
      Command::Unsupported(_) =>
        raise Smt2Error::Unsupported("unsupported command")
    }
  }
  output
}

///|
pub fn run_smt2(source : String) -> Array[StringView] raise Smt2Error {
  let exprs = @parser.parse_smtlib(source) catch {
    err => raise Smt2Error::Malformed(err.to_string())
  }
  let script = parse_script(exprs)
  let runner = Runner::new()
  runner.execute(script)
}
