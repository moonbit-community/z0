///|
pub fn ParamDescrs::add_smt_setup_defaults(self : ParamDescrs) -> Unit {
  self.add_string_with_policy(
    "smt.setup_mode",
    "basic",
    "smt",
    "SMT theory setup mode: basic, logic, or auto",
    ParamLifecycle::setup_only(),
    10,
    true,
  )
  self.add_bool_with_policy(
    "smt.auto_config",
    true,
    "smt",
    "enable static-feature based SMT theory setup",
    ParamLifecycle::setup_only(),
    20,
    true,
  )
}
