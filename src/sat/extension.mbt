///|
pub struct ExtConstraintId {
  priv value : Int32
} derive(Eq, Compare, Hash)

///|
#deprecated
#doc(hidden)
pub extend ExtConstraintId with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ExtConstraintId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated
#doc(hidden)
pub extend ExtConstraintId with Hash::{hash, hash_combine}

///|
pub fn ExtConstraintId::new(value : Int32) -> ExtConstraintId {
  { value, }
}

///|
pub fn ExtConstraintId::to_int(self : ExtConstraintId) -> Int32 {
  self.value
}

///|
pub impl Show for ExtConstraintId with fn output(self, logger) {
  logger.write_string("ext-constraint#\{self.value}")
}

///|
#deprecated
#doc(hidden)
pub extend ExtConstraintId with Show::{to_string, output}

///|
pub struct ExtJustificationId {
  priv value : Int32
} derive(Eq, Compare, Hash)

///|
#deprecated
#doc(hidden)
pub extend ExtJustificationId with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ExtJustificationId with Compare::{
  op_lt,
  op_le,
  op_ge,
  compare,
  op_gt,
}

///|
#deprecated
#doc(hidden)
pub extend ExtJustificationId with Hash::{hash, hash_combine}

///|
pub fn ExtJustificationId::new(value : Int32) -> ExtJustificationId {
  { value, }
}

///|
pub fn ExtJustificationId::to_int(self : ExtJustificationId) -> Int32 {
  self.value
}

///|
pub impl Show for ExtJustificationId with fn output(self, logger) {
  logger.write_string("ext-justification#\{self.value}")
}

///|
#deprecated
#doc(hidden)
pub extend ExtJustificationId with Show::{to_string, output}

///|
pub(all) enum WatchAction {
  KeepWatch
  DropWatch
} derive(Eq)

///|
#deprecated
#doc(hidden)
pub extend WatchAction with Eq::{not_equal, equal}

///|
pub(all) enum ExtensionAction {
  ExtensionNoAction
  ExtensionAssign(Literal, ExtJustificationId)
  ExtensionConflict(ExtJustificationId)
  ExtensionUnknown(@util.ReasonUnknown)
} derive(Eq)

///|
#deprecated
#doc(hidden)
pub extend ExtensionAction with Eq::{not_equal, equal}

///|
pub struct SatAssignmentView {
  priv assignments : Array[Bool?]
} derive(Eq)

///|
#deprecated
#doc(hidden)
pub extend SatAssignmentView with Eq::{not_equal, equal}

///|
pub fn SatAssignmentView::value(
  self : SatAssignmentView,
  bool_var : BoolVar,
) -> Bool? {
  match self.assignments.get(bool_var.to_int()) {
    Some(value) => value
    None => None
  }
}

///|
pub(all) struct SatExtension {
  init_search : () -> ExtensionAction
  tracking_assumptions : () -> Array[Literal]
  add_assumptions : (Array[Literal]) -> Unit
  should_research : (AssumptionCore) -> Bool
  can_propagate : () -> Bool
  unit_propagate : () -> ExtensionAction
  propagated : (Literal, ExtConstraintId) -> WatchAction
  asserted : (Literal) -> Unit
  is_external : (BoolVar) -> Bool
  set_eliminated : (BoolVar) -> Unit
  get_antecedents : (ExtJustificationId) -> Array[Literal]
  describe_justification : (ExtJustificationId) -> ClauseStatus
  check : (SatAssignmentView) -> ExtensionAction
  reason_unknown : () -> @util.ReasonUnknown?
  collect_statistics : () -> @stats.Statistics
  validate : (SatAssignmentView) -> @util.Availability[Unit]
  init_use_list : () -> Unit
  gc : () -> Unit
  gc_vars : (BoolVar) -> Unit
  is_blocked : (ExtConstraintId) -> Bool
}

///|
pub fn SatExtension::no_extension() -> SatExtension {
  {
    init_search: fn() { ExtensionNoAction },
    tracking_assumptions: fn() { [] },
    add_assumptions: fn(_) { () },
    should_research: fn(_) { false },
    can_propagate: fn() { false },
    unit_propagate: fn() { ExtensionNoAction },
    propagated: fn(_, _) { KeepWatch },
    asserted: fn(_) { () },
    is_external: fn(_) { false },
    set_eliminated: fn(_) { () },
    get_antecedents: fn(_) { [] },
    describe_justification: fn(_) { Redundant },
    check: fn(_) { ExtensionNoAction },
    reason_unknown: fn() { None },
    collect_statistics: fn() { @stats.Statistics::new() },
    validate: fn(_) { Available(()) },
    init_use_list: fn() { () },
    gc: fn() { () },
    gc_vars: fn(_) { () },
    is_blocked: fn(_) { false },
  }
}

///|
priv struct ExternalWatch {
  literal : Literal
  constraint : ExtConstraintId
}
