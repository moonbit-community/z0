///|
pub struct CommandContext {
  priv mut manager : @ast.AstManager
  priv factory : @solver.SolverFactory
  priv mut solver : @solver.Solver
  priv options : Options
  priv mut resource_limit : @util.ResourceLimit
  priv cancel_flag : @util.CancelFlag
  priv output_lines : Array[String]
  priv stderr_lines : Array[String]
  priv mut logic : String?
  priv mut exited : Bool
}

///|
pub fn CommandContext::new(factory : @solver.SolverFactory) -> CommandContext {
  CommandContext::new_with_factory(factory)
}

///|
pub fn CommandContext::new_with_factory(
  factory : @solver.SolverFactory,
) -> CommandContext {
  let manager = @ast.AstManager::new()
  CommandContext::{
    manager,
    factory,
    solver: factory.create(manager, @solver.SolverFactoryConfig::new()),
    options: Options::new(),
    resource_limit: @util.ResourceLimit::unlimited(),
    cancel_flag: @util.CancelFlag::new(),
    output_lines: [],
    stderr_lines: [],
    logic: None,
    exited: false,
  }
}

///|
pub fn CommandContext::manager(self : CommandContext) -> @ast.AstManager {
  self.manager
}

///|
pub fn CommandContext::produce_models(self : CommandContext) -> Bool {
  self.options.produce_models()
}

///|
pub fn CommandContext::produce_proofs(self : CommandContext) -> Bool {
  self.options.produce_proofs()
}

///|
pub fn CommandContext::produce_unsat_cores(self : CommandContext) -> Bool {
  self.options.produce_unsat_cores()
}

///|
pub fn CommandContext::produce_unsat_assumptions(self : CommandContext) -> Bool {
  self.options.produce_unsat_assumptions()
}

///|
pub fn CommandContext::global_decls(self : CommandContext) -> Bool {
  self.options.global_decls()
}

///|
pub fn CommandContext::diagnostic_output_channel(
  self : CommandContext,
) -> String {
  self.options.diagnostic_output_channel()
}

///|
pub fn CommandContext::regular_output_channel(self : CommandContext) -> String {
  self.options.regular_output_channel()
}

///|
pub fn CommandContext::error_behavior(self : CommandContext) -> String {
  self.options.error_behavior()
}

///|
pub fn CommandContext::append_runner_message(
  self : CommandContext,
  message : String,
) -> Unit {
  let display = runner_error_display_text(message)
  if self.options.diagnostic_output_channel_explicit() {
    self.append_diagnostic_line(display)
  } else {
    self.append_line(display)
  }
}

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
pub fn CommandContext::cancel_api(self : CommandContext) -> Unit {
  self.cancel_flag.cancel_api()
}

///|
pub fn CommandContext::cancel_user(self : CommandContext) -> Unit {
  self.cancel_flag.cancel_user()
}

///|
pub fn CommandContext::reset_cancel(self : CommandContext) -> Unit {
  self.cancel_flag.reset()
}

///|
pub fn CommandContext::is_canceled(self : CommandContext) -> Bool {
  self.cancel_flag.is_canceled()
}

///|
pub fn CommandContext::exited(self : CommandContext) -> Bool {
  self.exited
}

///|
fn CommandContext::append_line(self : CommandContext, line : String) -> Unit {
  if self.options.regular_output_channel() == "stderr" {
    self.stderr_lines.push(line)
  } else {
    self.output_lines.push(line)
  }
}

///|
fn CommandContext::append_diagnostic_line(
  self : CommandContext,
  line : String,
) -> Unit {
  if self.options.diagnostic_output_channel() == "stderr" {
    self.stderr_lines.push(line)
  } else {
    self.output_lines.push(line)
  }
}

///|
fn render_output_lines(lines : Array[String]) -> String {
  if lines.is_empty() {
    ""
  } else {
    let builder = StringBuilder::new()
    for line in lines {
      builder.write_string(line)
      builder.write_char('\n')
    }
    builder.to_string()
  }
}

///|
pub fn CommandContext::output(self : CommandContext) -> String {
  render_output_lines(self.output_lines)
}

///|
pub fn CommandContext::stderr_output(self : CommandContext) -> String {
  render_output_lines(self.stderr_lines)
}

///|
fn CommandContext::get_value_text(
  self : CommandContext,
  terms : Array[ModelQueryTerm],
) -> String {
  let builder = StringBuilder::new()
  builder.write_char('(')
  for i in 0..<terms.length() {
    let term = terms[i]
    match self.solver.get_value(term.expr()) {
      @util.Available(value) => {
        if i > 0 {
          builder.write_char(' ')
        }
        builder.write_char('(')
        builder.write_string(term.display())
        builder.write_char(' ')
        builder.write_string(value.format_smt2())
        builder.write_char(')')
      }
      @util.Unavailable(@util.AvailabilityReason::Disabled(_)) =>
        return "error: model production is disabled"
      @util.Unavailable(reason) =>
        return "error: value is not available: \{reason.to_text()}"
    }
  }
  builder.write_char(')')
  builder.to_string()
}

///|
fn CommandContext::maybe_print_success(self : CommandContext) -> Unit {
  if self.options.print_success() {
    self.append_line("success")
  }
}

///|
fn CommandContext::set_logic(
  self : CommandContext,
  logic : String,
) -> Unit raise {
  match self.logic {
    Some(_) => raise @solver_error.SolverError("logic is already set")
    None =>
      if self.solver.get_num_assertions() > 0 {
        raise @solver_error.SolverError(
          "cannot set logic after assertions have been added",
        )
      } else {
        match logic {
          "QF_UF" | "ALL" => self.logic = Some(logic)
          "QF_BOOL" =>
            raise @unsupported_error.UnsupportedError(
              "unsupported logic: QF_BOOL",
              None,
            )
          _ =>
            raise @unsupported_error.UnsupportedError(
              "unsupported logic: \{logic}",
              None,
            )
        }
      }
  }
}

///|
fn CommandContext::assert_expr(
  self : CommandContext,
  expr : @util.ExprId,
) -> Unit raise @type_error.TypeError {
  let expanded = @rewriter.expand_macros(self.manager, expr)
  match
    self.solver.assert_expr(@rewriter.rewrite_bool(self.manager, expanded)) {
    @util.Available(_) => ()
    @util.Unavailable(reason) =>
      raise @type_error.TypeError(reason.to_text(), None)
  }
}

///|
fn CommandContext::assert_named_expr(
  self : CommandContext,
  expr : @util.ExprId,
  name : String,
) -> Unit raise @type_error.TypeError {
  let expanded = @rewriter.expand_macros(self.manager, expr)
  let rewritten = @rewriter.rewrite_bool(self.manager, expanded)
  if self.manager.expr_sort(rewritten) != self.manager.bool_sort() {
    raise @type_error.TypeError("expected Bool named assertion", None)
  }
  if self.manager.lookup_decl(name) is Some(_) ||
    self.manager.lookup_macro(name) is Some(_) {
    raise @type_error.TypeError("declaration already exists: \{name}", None)
  }
  self.manager.push_scope()
  let tracker_decl = self.manager.declare_const(name, self.manager.bool_sort())
  let tracker_expr = self.manager.mk_app(tracker_decl, [])
  match
    self.solver.assert_expr_tracked(
      rewritten,
      @solver.TrackedExpr::new(tracker_expr, Some(name)),
    ) {
    @util.Available(_) =>
      self.manager.commit_scope(1) catch {
        err => raise @type_error.TypeError(err.to_string(), None)
      }
    @util.Unavailable(reason) => {
      self.manager.pop_scope(1) catch {
        err => raise @type_error.TypeError(err.to_string(), None)
      }
      raise @type_error.TypeError(reason.to_text(), None)
    }
  }
}

///|
fn CommandContext::push_scopes(
  self : CommandContext,
  count : Int,
) -> Unit raise @solver_error.SolverError {
  if count < 0 {
    raise @solver_error.SolverError("cannot push a negative number of scopes")
  } else {
    match self.solver.push(count) {
      @util.Available(_) => ()
      @util.Unavailable(reason) =>
        raise @solver_error.SolverError(reason.to_text())
    }
    if !self.options.global_decls() {
      for _ in 0..<count {
        self.manager.push_scope()
      }
    }
  }
}

///|
fn CommandContext::pop_scopes(
  self : CommandContext,
  count : Int,
) -> Unit raise @solver_error.SolverError {
  match self.solver.pop(count) {
    @util.Available(_) => ()
    @util.Unavailable(reason) =>
      raise @solver_error.SolverError(command_solver_reason_text(reason))
  }
  if !self.options.global_decls() {
    self.manager.pop_scope(count)
  }
}

///|
fn command_solver_reason_text(reason : @util.AvailabilityReason) -> String {
  match reason {
    @util.AvailabilityReason::Unsupported(
      @util.ReasonUnknown::UnsupportedFragment(fragment)
    ) =>
      if fragment == "invalid-pop" || fragment.has_prefix("late-option:") {
        fragment
      } else {
        reason.to_text()
      }
    _ => reason.to_text()
  }
}

///|
fn CommandContext::solver_config_from_options(
  self : CommandContext,
) -> @solver.SolverFactoryConfig {
  let config = @solver.SolverFactoryConfig::new()
  match self.logic {
    Some(logic) => ignore(config.with_logic(logic))
    None => ()
  }
  ignore(config.with_produce_models(self.options.produce_models()))
  ignore(config.with_produce_proofs(self.options.produce_proofs()))
  ignore(config.with_produce_unsat_cores(self.options.produce_unsat_cores()))
  ignore(
    config.with_produce_unsat_assumptions(
      self.options.produce_unsat_assumptions(),
    ),
  )
  config
}

///|
fn CommandContext::reset_assertions(
  self : CommandContext,
) -> Unit raise @solver_error.SolverError {
  let scope_depth = self.solver.get_scope_level()
  let next_solver = self.factory.create(
    self.manager,
    self.solver_config_from_options(),
  )
  if scope_depth > 0 {
    match next_solver.push(scope_depth) {
      @util.Available(_) => ()
      @util.Unavailable(reason) =>
        raise @solver_error.SolverError(reason.to_text())
    }
  }
  self.solver = next_solver
}

///|
fn CommandContext::reset(self : CommandContext) -> Unit {
  let next_manager = @ast.AstManager::new()
  self.logic = None
  self.manager = next_manager
  self.solver = self.factory.create(
    next_manager,
    self.solver_config_from_options(),
  )
}

///|
fn result_line(result : @solver.CheckSatResult) -> String {
  result.to_text()
}

///|
fn CommandContext::check_sat_assuming(
  self : CommandContext,
  assumptions : Array[@util.ExprId],
) -> @solver.CheckSatResult {
  let set = @solver.AssumptionSet::new()
  for assumption in assumptions {
    set.add(assumption)
  }
  self.solver.check_sat_assuming(set)
}

///|
fn CommandContext::assumption_set_text(
  self : CommandContext,
  assumptions : @solver.UnsatAssumptionSet,
) -> String {
  [
    for assumption in assumptions.items() => self.manager.pretty(assumption)
  ].join(",")
}

///|
fn parse_command_bool_option(
  name : String,
  value : String,
) -> Bool raise @parse_error.ParseError {
  match parse_bool_option(value) {
    Some(parsed) => parsed
    None => raise @parse_error.ParseError("\{name} expects true or false", None)
  }
}

///|
fn CommandContext::set_option(
  self : CommandContext,
  name : String,
  value : String,
) -> Unit raise {
  if name == ":produce-models" {
    let parsed = parse_command_bool_option(name, value)
    match self.solver.set_produce_models(parsed) {
      @util.Available(_) => ()
      @util.Unavailable(reason) =>
        raise @solver_error.SolverError(command_solver_reason_text(reason))
    }
    self.options.set(name, value)
  } else if name == ":produce-proofs" {
    let parsed = parse_command_bool_option(name, value)
    match self.solver.set_produce_proofs(parsed) {
      @util.Available(_) => ()
      @util.Unavailable(reason) =>
        raise @solver_error.SolverError(command_solver_reason_text(reason))
    }
    self.options.set(name, value)
  } else if name == ":produce-unsat-cores" {
    let parsed = parse_command_bool_option(name, value)
    match self.solver.set_produce_unsat_cores(parsed) {
      @util.Available(_) => ()
      @util.Unavailable(reason) =>
        raise @solver_error.SolverError(command_solver_reason_text(reason))
    }
    self.options.set(name, value)
  } else if name == ":produce-unsat-assumptions" {
    let parsed = parse_command_bool_option(name, value)
    match self.solver.set_produce_unsat_assumptions(parsed) {
      @util.Available(_) => ()
      @util.Unavailable(reason) =>
        raise @solver_error.SolverError(command_solver_reason_text(reason))
    }
    self.options.set(name, value)
  } else if name == ":global-decls" || name == ":global-declarations" {
    if self.solver.get_scope_level() > 0 {
      raise @solver_error.SolverError(
        "cannot set :global-decls while scopes are active",
      )
    }
    self.options.set(name, value)
  } else {
    self.options.set(name, value)
    if name == ":reproducible-resource-limit" {
      match self.options.reproducible_resource_limit() {
        Some(limit) =>
          self.resource_limit = @util.ResourceLimit::with_step_limit(limit)
        None => self.resource_limit = @util.ResourceLimit::unlimited()
      }
    }
  }
}

///|
fn CommandContext::checkpoint_limits(
  self : CommandContext,
) -> Unit raise @solver_error.SolverError {
  match self.cancel_flag.checkpoint() {
    @util.Available(_) => ()
    @util.Unavailable(reason) =>
      raise @solver_error.SolverError(reason.to_text())
  }
  match self.resource_limit.checkpoint() {
    @util.Available(_) => ()
    @util.Unavailable(reason) =>
      raise @solver_error.SolverError(reason.to_text())
  }
}

///|
fn CommandContext::statistics_info_text(self : CommandContext) -> String {
  let snapshot = self.solver.collect_statistics()
  let keys = snapshot.keys_text()
  let reasons = snapshot.incomplete_reasons_text()
  if keys.is_empty() && reasons.is_empty() {
    "(:all-statistics)"
  } else if reasons.is_empty() {
    "(:all-statistics \{keys})"
  } else if keys.is_empty() {
    "(:all-statistics :incomplete-reasons \{reasons})"
  } else {
    "(:all-statistics \{keys} :incomplete-reasons \{reasons})"
  }
}

///|
fn CommandContext::reason_unknown_info_text(self : CommandContext) -> String {
  match self.solver.reason_unknown() {
    @util.Available(reason) => "(:reason-unknown \{reason.to_text()})"
    @util.Unavailable(reason) => "(:reason-unknown \{reason.to_text()})"
  }
}

///|
fn CommandContext::get_info(self : CommandContext, name : String) -> Unit raise {
  match name {
    ":error-behavior" =>
      self.append_line("(:error-behavior \{self.options.error_behavior()})")
    ":rlimit" =>
      self.append_line("(:rlimit \{self.resource_limit.used_steps()})")
    ":all-statistics" => self.append_line(self.statistics_info_text())
    ":reason-unknown" => self.append_line(self.reason_unknown_info_text())
    _ =>
      raise @unsupported_error.UnsupportedError(
        "unsupported get-info: \{name}",
        None,
      )
  }
}

///|
fn CommandContext::execute_checked(
  self : CommandContext,
  command : Command,
) -> Unit raise {
  match command {
    SetLogic(logic) => self.set_logic(logic)
    SetOption(name, value) => self.set_option(name, value)
    SetInfo(_, _) => ()
    GetOption(name) => self.append_line(self.options.value_text(name))
    DeclareSort(name, arity) => ignore(self.manager.declare_sort(name, arity))
    DeclareConst(name, sort) => ignore(self.manager.declare_const(name, sort))
    DeclareFun(name, domain, range) =>
      ignore(self.manager.declare_fun(name, domain, range))
    DefineFun(name, params, range, body) =>
      if !params.is_empty() || range != self.manager.bool_sort() {
        raise @unsupported_error.UnsupportedError(
          "only nullary Bool define-fun is supported",
          None,
        )
      } else {
        self.manager.define_bool_macro(name, body)
      }
    Assert(expr) => self.assert_expr(expr)
    AssertNamed(expr, name) => self.assert_named_expr(expr, name)
    Push(count) => self.push_scopes(count)
    Pop(count) => self.pop_scopes(count)
    Reset => self.reset()
    ResetAssertions => self.reset_assertions()
    CheckSat => self.append_line(result_line(self.solver.check_sat()))
    CheckSatAssuming(assumptions) =>
      self.append_line(result_line(self.check_sat_assuming(assumptions)))
    GetModel =>
      match self.solver.get_model_text() {
        @util.Available(model_text) => self.append_line(model_text)
        @util.Unavailable(@util.AvailabilityReason::Disabled(_)) =>
          self.append_line("error: model production is disabled")
        @util.Unavailable(reason) =>
          self.append_line("error: model is not available: \{reason.to_text()}")
      }
    GetValue(terms) => self.append_line(self.get_value_text(terms))
    Eval(term, completion) =>
      match self.solver.eval(term.expr(), completion~) {
        @util.Available(value) => self.append_line(value.format_smt2())
        @util.Unavailable(@util.AvailabilityReason::Disabled(_)) =>
          self.append_line("error: model production is disabled")
        @util.Unavailable(reason) =>
          self.append_line("error: eval is not available: \{reason.to_text()}")
      }
    GetProof =>
      match self.solver.get_proof() {
        @util.Available(proof) => self.append_line(proof.to_text())
        @util.Unavailable(@util.AvailabilityReason::Disabled(_)) =>
          self.append_line("error: proof production is disabled")
        @util.Unavailable(reason) =>
          self.append_line("error: proof is not available: \{reason.to_text()}")
      }
    GetUnsatCore =>
      match self.solver.get_unsat_core() {
        @util.Available(core) =>
          self.append_line(
            core.to_text_with_expr(fn(expr) { self.manager.pretty(expr) }),
          )
        @util.Unavailable(@util.AvailabilityReason::Disabled(_)) =>
          self.append_line("error: unsat core production is disabled")
        @util.Unavailable(reason) =>
          self.append_line(
            "error: unsat core is not available: \{reason.to_text()}",
          )
      }
    GetUnsatAssumptions =>
      match self.solver.get_unsat_assumptions() {
        @util.Available(assumptions) =>
          self.append_line(self.assumption_set_text(assumptions))
        @util.Unavailable(@util.AvailabilityReason::Disabled(_)) =>
          self.append_line("error: unsat assumption production is disabled")
        @util.Unavailable(reason) =>
          self.append_line(
            "error: unsat assumptions are not available: \{reason.to_text()}",
          )
      }
    GetInfo(name) => self.get_info(name)
    Echo(value) => self.append_line(value)
    Exit => self.exited = true
  }
}

///|
fn command_prints_success(command : Command) -> Bool {
  match command {
    SetLogic(_)
    | SetOption(_, _)
    | SetInfo(_, _)
    | DeclareSort(_, _)
    | DeclareConst(_, _)
    | DeclareFun(_, _, _)
    | DefineFun(_, _, _, _)
    | Assert(_)
    | AssertNamed(_, _)
    | Push(_)
    | Pop(_)
    | Reset
    | ResetAssertions
    | Exit => true
    CheckSat
    | CheckSatAssuming(_)
    | GetOption(_)
    | GetModel
    | GetValue(_)
    | Eval(_, _)
    | GetProof
    | GetUnsatCore
    | GetUnsatAssumptions
    | GetInfo(_)
    | Echo(_) => false
  }
}

///|
pub fn CommandContext::execute(
  self : CommandContext,
  command : Command,
) -> Unit raise {
  self.checkpoint_limits()
  self.execute_checked(command)
  if command_prints_success(command) {
    self.maybe_print_success()
  }
}
