///|
fn bool_param_to_text(value : @util.Availability[Bool]) -> String {
  match value {
    @util.Available(v) => "bool:\{v}"
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
fn int_param_to_text(value : @util.Availability[Int]) -> String {
  match value {
    @util.Available(v) => "int:\{v}"
    @util.Unavailable(reason) => reason.to_text()
  }
}

///|
test "params_return_descriptor_defaults" {
  let descrs = ParamDescrs::new()
  descrs.add_bool("produce_models", false, "solver", "enable model queries")
  descrs.add_int("max_conflicts", 0, "sat", "maximum conflicts before unknown")
  let params = Params::new(descrs)
  inspect(
    bool_param_to_text(params.get_bool("produce_models")),
    content="bool:false",
  )
  inspect(int_param_to_text(params.get_int("max_conflicts")), content="int:0")
}

///|
test "params_set_typed_values" {
  let descrs = ParamDescrs::new()
  descrs.add_bool("produce_models", false, "solver", "enable model queries")
  let params = Params::new(descrs)
  inspect(
    bool_param_to_text(params.set_bool("produce_models", true)),
    content="bool:true",
  )
  inspect(
    bool_param_to_text(params.get_bool("produce_models")),
    content="bool:true",
  )
}

///|
test "params_report_unknown_key" {
  let params = Params::new(ParamDescrs::new())
  inspect(
    bool_param_to_text(params.get_bool("missing")),
    content="unsupported(unknown-param:missing)",
  )
}

///|
test "param_descriptors_keep_stable_owner_metadata" {
  let descrs = ParamDescrs::new()
  descrs.add_string("logic", "ALL", "solver", "selected SMT logic")
  inspect(descrs.owner("logic"), content="solver")
  inspect(descrs.kind_text("logic"), content="string")
}

///|
test "solver_model_proof_descriptors_have_stable_keys" {
  let descrs = ParamDescrs::new()
  descrs.add_solver_model_proof_defaults()
  inspect(
    descrs.keys_text(),
    content="produce_models,produce_proofs,produce_unsat_cores,produce_unsat_assumptions,model_completion,proof_check",
  )
  inspect(descrs.owner("produce_models"), content="model")
  inspect(descrs.owner("produce_proofs"), content="proof")
  let params = Params::new(descrs)
  inspect(
    bool_param_to_text(params.get_bool("produce_models")),
    content="bool:false",
  )
}

///|
test "smt_setup_descriptors_have_stable_keys" {
  let descrs = ParamDescrs::new()
  descrs.add_smt_setup_defaults()
  inspect(descrs.keys_text(), content="smt.setup_mode,smt.auto_config")
  inspect(descrs.kind_text("smt.setup_mode"), content="string")
  inspect(descrs.owner("smt.auto_config"), content="smt")
}

///|
test "param_descriptors_record_lifecycle_policy" {
  let descrs = ParamDescrs::new()
  descrs.add_bool_with_policy(
    "smt.auto_config",
    true,
    "smt",
    "enable SMT auto config",
    ParamLifecycle::setup_only(),
    10,
    true,
  )
  descrs.add_bool_with_policy(
    "produce_models",
    false,
    "model",
    "enable model queries",
    ParamLifecycle::dynamic(),
    30,
    false,
  )
  inspect(descrs.lifecycle_text("smt.auto_config"), content="setup-only")
  inspect(descrs.apply_order("smt.auto_config"), content="10")
  inspect(descrs.requires_reset("smt.auto_config"), content="true")
  inspect(descrs.lifecycle_text("produce_models"), content="dynamic")
  inspect(descrs.apply_order("produce_models"), content="30")
  inspect(descrs.requires_reset("produce_models"), content="false")
}

///|
test "params_reject_late_setup_and_pre_assertion_sets" {
  let descrs = ParamDescrs::new()
  descrs.add_bool_with_policy(
    "smt.auto_config",
    true,
    "smt",
    "enable SMT auto config",
    ParamLifecycle::setup_only(),
    10,
    true,
  )
  descrs.add_bool_with_policy(
    "produce_proofs",
    false,
    "proof",
    "enable proof query results",
    ParamLifecycle::pre_assertion(),
    20,
    true,
  )
  descrs.add_bool_with_policy(
    "produce_models",
    false,
    "model",
    "enable model query results",
    ParamLifecycle::dynamic(),
    30,
    false,
  )
  let params = Params::new(descrs)
  inspect(
    bool_param_to_text(
      params.set_bool_at(
        "smt.auto_config",
        false,
        ParamSetStage::post_assertion(),
      ),
    ),
    content="unsupported(param-late-set:smt.auto_config:setup-only:post-assertion)",
  )
  inspect(
    bool_param_to_text(
      params.set_bool_at(
        "produce_proofs",
        true,
        ParamSetStage::post_assertion(),
      ),
    ),
    content="unsupported(param-late-set:produce_proofs:pre-assertion:post-assertion)",
  )
  inspect(
    bool_param_to_text(
      params.set_bool_at(
        "produce_models",
        true,
        ParamSetStage::post_assertion(),
      ),
    ),
    content="bool:true",
  )
}
