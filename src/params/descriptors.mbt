///|
pub(all) enum ParamKind {
  BoolParam
  IntParam
  StringParam
} derive(Eq)

///|
fn ParamKind::to_text(self : ParamKind) -> String {
  match self {
    BoolParam => "bool"
    IntParam => "int"
    StringParam => "string"
  }
}

///|
pub(all) enum ParamValue {
  BoolValue(Bool)
  IntValue(Int)
  StringValue(String)
} derive(Eq)

///|
pub(all) enum ParamLifecycle {
  SetupOnly
  PreAssertion
  PerCheck
  Dynamic
} derive(Eq)

///|
pub fn ParamLifecycle::setup_only() -> ParamLifecycle {
  SetupOnly
}

///|
pub fn ParamLifecycle::pre_assertion() -> ParamLifecycle {
  PreAssertion
}

///|
pub fn ParamLifecycle::per_check() -> ParamLifecycle {
  PerCheck
}

///|
pub fn ParamLifecycle::dynamic() -> ParamLifecycle {
  Dynamic
}

///|
fn ParamLifecycle::to_text(self : ParamLifecycle) -> String {
  match self {
    SetupOnly => "setup-only"
    PreAssertion => "pre-assertion"
    PerCheck => "per-check"
    Dynamic => "dynamic"
  }
}

///|
pub(all) enum ParamSetStage {
  SetupStage
  PreAssertionStage
  PostAssertionStage
  PerCheckStage
} derive(Eq)

///|
pub fn ParamSetStage::setup() -> ParamSetStage {
  SetupStage
}

///|
pub fn ParamSetStage::pre_assertion() -> ParamSetStage {
  PreAssertionStage
}

///|
pub fn ParamSetStage::post_assertion() -> ParamSetStage {
  PostAssertionStage
}

///|
pub fn ParamSetStage::per_check() -> ParamSetStage {
  PerCheckStage
}

///|
fn ParamSetStage::to_text(self : ParamSetStage) -> String {
  match self {
    SetupStage => "setup"
    PreAssertionStage => "pre-assertion"
    PostAssertionStage => "post-assertion"
    PerCheckStage => "per-check"
  }
}

///|
fn ParamLifecycle::allows_set(
  self : ParamLifecycle,
  stage : ParamSetStage,
) -> Bool {
  match self {
    SetupOnly => stage == SetupStage
    PreAssertion => stage == SetupStage || stage == PreAssertionStage
    PerCheck => true
    Dynamic => true
  }
}

///|
priv struct ParamDescriptor {
  name : String
  kind : ParamKind
  default : ParamValue
  owner : String
  description : String
  lifecycle : ParamLifecycle
  apply_order : Int
  requires_reset : Bool
}

///|
pub struct ParamDescrs {
  priv entries : Array[ParamDescriptor]
}

///|
pub fn ParamDescrs::new() -> ParamDescrs {
  { entries: [] }
}

///|
pub fn ParamDescrs::add_bool(
  self : ParamDescrs,
  name : String,
  default : Bool,
  owner : String,
  description : String,
) -> Unit {
  self.add_bool_with_policy(
    name,
    default,
    owner,
    description,
    ParamLifecycle::dynamic(),
    0,
    false,
  )
}

///|
pub fn ParamDescrs::add_bool_with_policy(
  self : ParamDescrs,
  name : String,
  default : Bool,
  owner : String,
  description : String,
  lifecycle : ParamLifecycle,
  apply_order : Int,
  requires_reset : Bool,
) -> Unit {
  self.entries.push(ParamDescriptor::{
    name,
    kind: BoolParam,
    default: BoolValue(default),
    owner,
    description,
    lifecycle,
    apply_order,
    requires_reset,
  })
}

///|
pub fn ParamDescrs::add_int(
  self : ParamDescrs,
  name : String,
  default : Int,
  owner : String,
  description : String,
) -> Unit {
  self.add_int_with_policy(
    name,
    default,
    owner,
    description,
    ParamLifecycle::dynamic(),
    0,
    false,
  )
}

///|
pub fn ParamDescrs::add_int_with_policy(
  self : ParamDescrs,
  name : String,
  default : Int,
  owner : String,
  description : String,
  lifecycle : ParamLifecycle,
  apply_order : Int,
  requires_reset : Bool,
) -> Unit {
  self.entries.push(ParamDescriptor::{
    name,
    kind: IntParam,
    default: IntValue(default),
    owner,
    description,
    lifecycle,
    apply_order,
    requires_reset,
  })
}

///|
pub fn ParamDescrs::add_string(
  self : ParamDescrs,
  name : String,
  default : String,
  owner : String,
  description : String,
) -> Unit {
  self.add_string_with_policy(
    name,
    default,
    owner,
    description,
    ParamLifecycle::dynamic(),
    0,
    false,
  )
}

///|
pub fn ParamDescrs::add_string_with_policy(
  self : ParamDescrs,
  name : String,
  default : String,
  owner : String,
  description : String,
  lifecycle : ParamLifecycle,
  apply_order : Int,
  requires_reset : Bool,
) -> Unit {
  self.entries.push(ParamDescriptor::{
    name,
    kind: StringParam,
    default: StringValue(default),
    owner,
    description,
    lifecycle,
    apply_order,
    requires_reset,
  })
}

///|
pub fn ParamDescrs::add_solver_model_proof_defaults(self : ParamDescrs) -> Unit {
  self.add_bool_with_policy(
    "produce_models",
    false,
    "model",
    "enable model query results",
    ParamLifecycle::dynamic(),
    10,
    false,
  )
  self.add_bool_with_policy(
    "produce_proofs",
    false,
    "proof",
    "enable proof query results",
    ParamLifecycle::pre_assertion(),
    20,
    true,
  )
  self.add_bool_with_policy(
    "produce_unsat_cores",
    false,
    "solver",
    "enable named-assertion unsat core results",
    ParamLifecycle::pre_assertion(),
    30,
    true,
  )
  self.add_bool_with_policy(
    "produce_unsat_assumptions",
    false,
    "solver",
    "enable check-sat-assuming unsat assumption results",
    ParamLifecycle::pre_assertion(),
    40,
    true,
  )
  self.add_bool_with_policy(
    "model_completion",
    false,
    "model",
    "complete missing model values during evaluation",
    ParamLifecycle::per_check(),
    50,
    false,
  )
  self.add_bool_with_policy(
    "proof_check",
    true,
    "proof",
    "check generated proof objects",
    ParamLifecycle::pre_assertion(),
    60,
    true,
  )
}

///|
fn ParamDescrs::find(self : ParamDescrs, name : String) -> ParamDescriptor? {
  for entry in self.entries {
    if entry.name == name {
      return Some(entry)
    }
  }
  None
}

///|
pub fn ParamDescrs::owner(self : ParamDescrs, name : String) -> String {
  match self.find(name) {
    Some(entry) => entry.owner
    None => ""
  }
}

///|
pub fn ParamDescrs::kind_text(self : ParamDescrs, name : String) -> String {
  match self.find(name) {
    Some(entry) => entry.kind.to_text()
    None => "unknown"
  }
}

///|
pub fn ParamDescrs::description(self : ParamDescrs, name : String) -> String {
  match self.find(name) {
    Some(entry) => entry.description
    None => ""
  }
}

///|
pub fn ParamDescrs::lifecycle_text(self : ParamDescrs, name : String) -> String {
  match self.find(name) {
    Some(entry) => entry.lifecycle.to_text()
    None => "unknown"
  }
}

///|
pub fn ParamDescrs::apply_order(self : ParamDescrs, name : String) -> Int {
  match self.find(name) {
    Some(entry) => entry.apply_order
    None => -1
  }
}

///|
pub fn ParamDescrs::requires_reset(self : ParamDescrs, name : String) -> Bool {
  match self.find(name) {
    Some(entry) => entry.requires_reset
    None => false
  }
}

///|
fn[T] param_late_set(
  name : String,
  lifecycle : ParamLifecycle,
  stage : ParamSetStage,
) -> @util.Availability[T] {
  @util.Unavailable(
    @util.AvailabilityReason::unsupported(
      @util.ReasonUnknown::unsupported_fragment(
        "param-late-set:\{name}:\{lifecycle.to_text()}:\{stage.to_text()}",
      ),
    ),
  )
}

///|
pub fn ParamDescrs::validate_set(
  self : ParamDescrs,
  name : String,
  stage : ParamSetStage,
) -> @util.Availability[Unit] {
  match self.find(name) {
    Some(entry) =>
      if entry.lifecycle.allows_set(stage) {
        @util.Available(())
      } else {
        param_late_set(name, entry.lifecycle, stage)
      }
    None => unknown_param(name)
  }
}

///|
pub fn ParamDescrs::keys_text(self : ParamDescrs) -> String {
  let keys : Array[String] = []
  for entry in self.entries {
    keys.push(entry.name)
  }
  let builder = StringBuilder::new()
  for i in 0..<keys.length() {
    if i > 0 {
      builder.write_char(',')
    }
    builder.write_string(keys[i])
  }
  builder.to_string()
}

///|
fn ParamDescrs::default_value(self : ParamDescrs, name : String) -> ParamValue? {
  match self.find(name) {
    Some(entry) => Some(entry.default)
    None => None
  }
}
