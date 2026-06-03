///|
priv struct ArithLiteVarState {
  name : String
  lower : Int?
  upper : Int?
  value : Int?
}

///|
pub(all) enum ArithLiteResult {
  ArithLiteSat
  ArithLiteUnsat(String)
  ArithLiteUnsupported(@util.ReasonUnknown)
} derive(Eq)

///|
pub fn ArithLiteResult::to_text(self : ArithLiteResult) -> String {
  match self {
    ArithLiteSat => "sat"
    ArithLiteUnsat(reason) => "unsat:\{reason}"
    ArithLiteUnsupported(reason) => "unsupported:\{reason.to_text()}"
  }
}

///|
pub struct ArithLiteProblem {
  priv vars : Array[ArithLiteVarState]
  priv mut unsupported : @util.ReasonUnknown?
}

///|
pub fn ArithLiteProblem::new() -> ArithLiteProblem {
  { vars: [], unsupported: None }
}

///|
fn ArithLiteProblem::find_index(self : ArithLiteProblem, name : String) -> Int {
  for i in 0..<self.vars.length() {
    if self.vars[i].name == name {
      return i
    }
  }
  -1
}

///|
fn ArithLiteProblem::ensure_index(
  self : ArithLiteProblem,
  name : String,
) -> Int {
  let index = self.find_index(name)
  if index >= 0 {
    index
  } else {
    self.vars.push(ArithLiteVarState::{
      name,
      lower: None,
      upper: None,
      value: None,
    })
    self.vars.length() - 1
  }
}

///|
pub fn ArithLiteProblem::assert_eq_const(
  self : ArithLiteProblem,
  name : String,
  value : Int,
) -> Unit {
  let index = self.ensure_index(name)
  self.vars[index] = ArithLiteVarState::{
    name,
    lower: Some(value),
    upper: Some(value),
    value: Some(value),
  }
}

///|
pub fn ArithLiteProblem::assert_ge_const(
  self : ArithLiteProblem,
  name : String,
  value : Int,
) -> Unit {
  let index = self.ensure_index(name)
  let old = self.vars[index]
  let lower = match old.lower {
    Some(bound) => Some(if value > bound { value } else { bound })
    None => Some(value)
  }
  self.vars[index] = ArithLiteVarState::{
    name,
    lower,
    upper: old.upper,
    value: old.value,
  }
}

///|
pub fn ArithLiteProblem::assert_le_const(
  self : ArithLiteProblem,
  name : String,
  value : Int,
) -> Unit {
  let index = self.ensure_index(name)
  let old = self.vars[index]
  let upper = match old.upper {
    Some(bound) => Some(if value < bound { value } else { bound })
    None => Some(value)
  }
  self.vars[index] = ArithLiteVarState::{
    name,
    lower: old.lower,
    upper,
    value: old.value,
  }
}

///|
pub fn ArithLiteProblem::reject_fragment(
  self : ArithLiteProblem,
  feature : String,
) -> Unit {
  self.unsupported = Some(@util.ReasonUnknown::unsupported_fragment(feature))
}

///|
fn var_state_conflict(state : ArithLiteVarState) -> String? {
  match (state.lower, state.upper) {
    (Some(lower), Some(upper)) =>
      if lower > upper {
        Some("\{state.name}:lower>\{upper}")
      } else {
        None
      }
    _ => None
  }
}

///|
pub fn ArithLiteProblem::check(self : ArithLiteProblem) -> ArithLiteResult {
  match self.unsupported {
    Some(reason) => ArithLiteUnsupported(reason)
    None =>
      for state in self.vars {
        match var_state_conflict(state) {
          Some(reason) => return ArithLiteUnsat(reason)
          None => ()
        }
      } nobreak {
        ArithLiteSat
      }
  }
}

///|
pub fn arith_lite_param_descrs() -> @params.ParamDescrs {
  let descrs = @params.ParamDescrs::new()
  descrs.add_bool(
    "arith_lite.enabled", true, "arith_lite", "enable the minimal arithmetic-lite theory skeleton",
  )
  descrs.add_int(
    "arith_lite.max-conflicts", 0, "arith_lite", "seed bound for deterministic arith-lite conflict budgeting",
  )
  descrs
}

///|
pub fn arith_lite_theory_plugin(
  id : @ids.TheoryId,
  family : @ast.FamilyId,
) -> @theory_core.TheoryPlugin {
  let plugin = @theory_core.TheoryPlugin::default_unimplemented(
    id,
    "arith_lite",
    [family],
  )
  plugin.set_describe_params(fn() { arith_lite_param_descrs() })
  plugin.set_updt_params(fn(_) { @util.Available(()) })
  plugin.set_internalize_term(fn(view, _, _, expr) {
    @theory_core.TheoryHandled(
      @theory_core.TheoryTermRef::new(
        id,
        expr.to_int(),
        scope_generation=view.scope_depth(),
      ),
    )
  })
  plugin.set_internalize_atom(fn(view, actions, family, expr) {
    plugin.internalize_term(view, actions, family, expr)
  })
  plugin.set_internalize_equality(fn(view, _, lhs, rhs) {
    @theory_core.TheoryHandled(
      @theory_core.TheoryTermRef::new(
        id,
        lhs.to_int() * 65536 + rhs.to_int(),
        scope_generation=view.scope_depth(),
      ),
    )
  })
  plugin.set_theory_check(fn(_, _) { @theory_core.TheoryCheckDone })
  plugin.set_mk_value(fn(_, _, term) { Some(@util.ExprId::new(term.to_int())) })
  plugin.set_collect_statistics(fn() {
    let statistics = @stats.Statistics::new()
    statistics.inc_counter("arith_lite.checks", 1)
    statistics
  })
  plugin
}

///|
pub fn arith_lite_theory_factory(
  id : @ids.TheoryId,
  family : @ast.FamilyId,
) -> @theory_core.TheoryFactory {
  @theory_core.TheoryFactory::new(
    @theory_core.TheoryFactoryDescriptor::new(
      id~,
      name="arith_lite",
      families=[family],
      logics=["QF_LIA", "QF_UFLIA", "ALL"],
      auto_config=true,
    ),
    fn() { arith_lite_theory_plugin(id, family) },
  )
}
