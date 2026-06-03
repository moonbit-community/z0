///|
pub struct SolverFactoryConfig {
  priv mut logic : String
  priv mut produce_models : Bool
  priv mut produce_proofs : Bool
  priv mut produce_unsat_cores : Bool
  priv mut produce_unsat_assumptions : Bool
  priv params : @params.Params
}

///|
fn solver_factory_param_descrs() -> @params.ParamDescrs {
  let descrs = @params.ParamDescrs::new()
  descrs.add_solver_model_proof_defaults()
  descrs
}

///|
pub fn SolverFactoryConfig::new() -> SolverFactoryConfig {
  let descrs = solver_factory_param_descrs()
  SolverFactoryConfig::{
    logic: "ALL",
    produce_models: false,
    produce_proofs: false,
    produce_unsat_cores: false,
    produce_unsat_assumptions: false,
    params: @params.Params::new(descrs),
  }
}

///|
pub fn SolverFactoryConfig::with_logic(
  self : SolverFactoryConfig,
  logic : String,
) -> SolverFactoryConfig {
  self.logic = logic
  self
}

///|
pub fn SolverFactoryConfig::with_produce_models(
  self : SolverFactoryConfig,
  value : Bool,
) -> SolverFactoryConfig {
  self.produce_models = value
  ignore(self.params.set_bool("produce_models", value))
  self
}

///|
pub fn SolverFactoryConfig::with_produce_proofs(
  self : SolverFactoryConfig,
  value : Bool,
) -> SolverFactoryConfig {
  self.produce_proofs = value
  ignore(self.params.set_bool("produce_proofs", value))
  self
}

///|
pub fn SolverFactoryConfig::with_produce_unsat_cores(
  self : SolverFactoryConfig,
  value : Bool,
) -> SolverFactoryConfig {
  self.produce_unsat_cores = value
  ignore(self.params.set_bool("produce_unsat_cores", value))
  self
}

///|
pub fn SolverFactoryConfig::with_produce_unsat_assumptions(
  self : SolverFactoryConfig,
  value : Bool,
) -> SolverFactoryConfig {
  self.produce_unsat_assumptions = value
  ignore(self.params.set_bool("produce_unsat_assumptions", value))
  self
}

///|
pub fn SolverFactoryConfig::logic(self : SolverFactoryConfig) -> String {
  self.logic
}

///|
pub fn SolverFactoryConfig::produce_models(self : SolverFactoryConfig) -> Bool {
  self.produce_models
}

///|
pub fn SolverFactoryConfig::produce_proofs(self : SolverFactoryConfig) -> Bool {
  self.produce_proofs
}

///|
pub fn SolverFactoryConfig::produce_unsat_cores(
  self : SolverFactoryConfig,
) -> Bool {
  self.produce_unsat_cores
}

///|
pub fn SolverFactoryConfig::produce_unsat_assumptions(
  self : SolverFactoryConfig,
) -> Bool {
  self.produce_unsat_assumptions
}

///|
pub fn SolverFactoryConfig::params(
  self : SolverFactoryConfig,
) -> @params.Params {
  self.params
}

///|
pub fn SolverFactoryConfig::describe_params(
  _self : SolverFactoryConfig,
) -> @params.ParamDescrs {
  solver_factory_param_descrs()
}

///|
pub struct SolverFactory {
  priv create_fn : (@ast.AstManager, SolverFactoryConfig) -> Solver
}

///|
pub fn SolverFactory::new(
  create : (@ast.AstManager, SolverFactoryConfig) -> Solver,
) -> SolverFactory {
  { create_fn: create }
}

///|
pub fn SolverFactory::create(
  self : SolverFactory,
  manager : @ast.AstManager,
  config : SolverFactoryConfig,
) -> Solver {
  (self.create_fn)(manager, config)
}
