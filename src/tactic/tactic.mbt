///|
pub struct TacticResult {
  priv goals : Array[Goal]
}

///|
pub fn TacticResult::from_goals(goals : Array[Goal]) -> TacticResult {
  { goals: goals.copy() }
}

///|
pub fn TacticResult::goal_count(self : TacticResult) -> Int {
  self.goals.length()
}

///|
pub fn TacticResult::goal(self : TacticResult, index : Int) -> Goal? {
  self.goals.get(index)
}

///|
pub struct Tactic {
  priv name : String
  priv apply_fn : (Goal) -> @util.Availability[TacticResult]
  priv mut collect_statistics_fn : () -> @stats.Statistics
  priv mut describe_params_fn : () -> @params.ParamDescrs
  priv mut updt_params_fn : (@params.Params) -> @util.Availability[Unit]
  priv mut set_logic_fn : (String) -> @util.Availability[Unit]
  priv mut translate_fn : (Tactic, @ast.AstTranslator) -> @util.Availability[
    Tactic,
  ]
  priv mut cleanup_fn : () -> @util.Availability[Unit]
}

///|
pub fn Tactic::new(
  name : String,
  apply : (Goal) -> @util.Availability[TacticResult],
) -> Tactic {
  {
    name,
    apply_fn: apply,
    collect_statistics_fn: fn() {
      let stats = @stats.Statistics::new()
      stats.inc_counter("tactic.\{name}.queries", 1)
      stats
    },
    describe_params_fn: fn() { @params.ParamDescrs::new() },
    updt_params_fn: fn(_) { @util.Available(()) },
    set_logic_fn: fn(_) { @util.Available(()) },
    translate_fn: fn(self, _) { @util.Available(self) },
    cleanup_fn: fn() { @util.Available(()) },
  }
}

///|
pub fn Tactic::name(self : Tactic) -> String {
  self.name
}

///|
pub fn Tactic::apply(
  self : Tactic,
  goal : Goal,
) -> @util.Availability[TacticResult] {
  (self.apply_fn)(goal)
}

///|
pub fn Tactic::skip() -> Tactic {
  Tactic::new("skip", fn(goal) {
    @util.Available(TacticResult::from_goals([goal]))
  })
}

///|
pub fn Tactic::fail(feature : String) -> Tactic {
  Tactic::new("fail:\{feature}", fn(_) {
    @util.Unavailable(
      @util.AvailabilityReason::unsupported(
        @util.ReasonUnknown::unsupported_fragment(feature),
      ),
    )
  })
}

///|
pub fn Tactic::collect_statistics(self : Tactic) -> @stats.Statistics {
  (self.collect_statistics_fn)()
}

///|
pub fn Tactic::set_collect_statistics(
  self : Tactic,
  collect_statistics : () -> @stats.Statistics,
) -> Unit {
  self.collect_statistics_fn = collect_statistics
}

///|
pub fn Tactic::describe_params(self : Tactic) -> @params.ParamDescrs {
  (self.describe_params_fn)()
}

///|
pub fn Tactic::set_describe_params(
  self : Tactic,
  describe_params : () -> @params.ParamDescrs,
) -> Unit {
  self.describe_params_fn = describe_params
}

///|
pub fn Tactic::updt_params(
  self : Tactic,
  params : @params.Params,
) -> @util.Availability[Unit] {
  (self.updt_params_fn)(params)
}

///|
pub fn Tactic::set_updt_params(
  self : Tactic,
  updt_params : (@params.Params) -> @util.Availability[Unit],
) -> Unit {
  self.updt_params_fn = updt_params
}

///|
pub fn Tactic::set_logic(
  self : Tactic,
  logic : String,
) -> @util.Availability[Unit] {
  (self.set_logic_fn)(logic)
}

///|
pub fn Tactic::set_logic_callback(
  self : Tactic,
  set_logic : (String) -> @util.Availability[Unit],
) -> Unit {
  self.set_logic_fn = set_logic
}

///|
pub fn Tactic::translate(
  self : Tactic,
  translator : @ast.AstTranslator,
) -> @util.Availability[Tactic] {
  (self.translate_fn)(self, translator)
}

///|
pub fn Tactic::set_translate(
  self : Tactic,
  translate : (@ast.AstTranslator) -> @util.Availability[Tactic],
) -> Unit {
  self.translate_fn = fn(_, translator) { translate(translator) }
}

///|
pub fn Tactic::cleanup(self : Tactic) -> @util.Availability[Unit] {
  (self.cleanup_fn)()
}

///|
pub fn Tactic::set_cleanup(
  self : Tactic,
  cleanup : () -> @util.Availability[Unit],
) -> Unit {
  self.cleanup_fn = cleanup
}
