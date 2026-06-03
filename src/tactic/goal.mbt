///|
pub(all) enum GoalPrecision {
  Precise
  Under
  Over
  UnderOver
} derive(Eq)

///|
pub fn GoalPrecision::to_text(self : GoalPrecision) -> String {
  match self {
    Precise => "precise"
    Under => "under"
    Over => "over"
    UnderOver => "under-over"
  }
}

///|
pub struct Goal {
  priv manager : @ast.AstManager
  priv formulas : Array[@util.ExprId]
  priv mut precision : GoalPrecision
  priv mut depth : Int
  priv mut reason_unknown : @util.ReasonUnknown?
  priv mut model_converter : @converters.ModelConverter
  priv mut proof_converter : @converters.ProofConverter
  priv dependency_converter : DependencyConverter
  priv mut requires_model : Bool
  priv mut requires_proof : Bool
  priv mut requires_unsat_core : Bool
}

///|
pub fn Goal::new(manager : @ast.AstManager) -> Goal {
  {
    manager,
    formulas: [],
    precision: Precise,
    depth: 0,
    reason_unknown: None,
    model_converter: @converters.ModelConverter::identity(),
    proof_converter: @converters.ProofConverter::identity(),
    dependency_converter: DependencyConverter::new(),
    requires_model: false,
    requires_proof: false,
    requires_unsat_core: false,
  }
}

///|
pub fn Goal::manager(self : Goal) -> @ast.AstManager {
  self.manager
}

///|
pub fn Goal::add(self : Goal, formula : @util.ExprId) -> Unit {
  self.formulas.push(formula)
}

///|
pub fn Goal::size(self : Goal) -> Int {
  self.formulas.length()
}

///|
pub fn Goal::formula(self : Goal, index : Int) -> @util.ExprId? {
  self.formulas.get(index)
}

///|
pub fn Goal::precision(self : Goal) -> GoalPrecision {
  self.precision
}

///|
pub fn Goal::set_precision(self : Goal, precision : GoalPrecision) -> Unit {
  self.precision = precision
}

///|
pub fn Goal::depth(self : Goal) -> Int {
  self.depth
}

///|
pub fn Goal::set_depth(self : Goal, depth : Int) -> Unit {
  self.depth = depth
}

///|
pub fn Goal::set_reason_unknown(
  self : Goal,
  reason : @util.ReasonUnknown,
) -> Unit {
  self.reason_unknown = Some(reason)
}

///|
pub fn Goal::reason_unknown_text(self : Goal) -> String {
  match self.reason_unknown {
    Some(reason) => reason.to_text()
    None => ""
  }
}

///|
pub fn Goal::model_converter(self : Goal) -> @converters.ModelConverter {
  self.model_converter
}

///|
fn Goal::append_model_converter(
  self : Goal,
  converter : @converters.ModelConverter,
) -> Unit {
  self.model_converter = self.model_converter.concat(converter)
}

///|
pub fn Goal::proof_converter(self : Goal) -> @converters.ProofConverter {
  self.proof_converter
}

///|
fn Goal::append_proof_converter(
  self : Goal,
  converter : @converters.ProofConverter,
) -> Unit {
  self.proof_converter = self.proof_converter.concat(converter)
}

///|
pub fn Goal::dependency_converter(self : Goal) -> DependencyConverter {
  self.dependency_converter
}

///|
pub fn Goal::requires_model(self : Goal) -> Bool {
  self.requires_model
}

///|
pub fn Goal::set_requires_model(self : Goal, value : Bool) -> Unit {
  self.requires_model = value
}

///|
pub fn Goal::requires_proof(self : Goal) -> Bool {
  self.requires_proof
}

///|
pub fn Goal::set_requires_proof(self : Goal, value : Bool) -> Unit {
  self.requires_proof = value
}

///|
pub fn Goal::requires_unsat_core(self : Goal) -> Bool {
  self.requires_unsat_core
}

///|
pub fn Goal::set_requires_unsat_core(self : Goal, value : Bool) -> Unit {
  self.requires_unsat_core = value
}

///|
pub fn Goal::sat_preserved(self : Goal) -> Bool {
  match self.precision {
    Precise | Under => true
    Over | UnderOver => false
  }
}

///|
pub fn Goal::unsat_preserved(self : Goal) -> Bool {
  match self.precision {
    Precise | Over => true
    Under | UnderOver => false
  }
}

///|
pub fn Goal::is_decided_sat(self : Goal) -> Bool {
  self.formulas.is_empty() && self.precision == Precise
}

///|
pub fn Goal::is_decided_unsat(self : Goal) -> Bool {
  if self.precision != Precise {
    return false
  }
  for formula in self.formulas {
    match self.manager.get_expr(formula).kind {
      @ast.BoolValue(false) => return true
      _ => ()
    }
  }
  false
}
