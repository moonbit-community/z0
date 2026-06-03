///|
pub struct ModelRef {
  priv id : Int
  priv result : @util.ResultKind
}

///|
pub fn ModelRef::to_text(self : ModelRef) -> String {
  "model#\{self.id}(\{self.result.to_text()})"
}

///|
pub struct ModelHandle {
  priv id : Int
  priv result : @util.ResultKind
  priv disabled : String?
  priv mut stale : Bool
}

///|
struct BoolConstInterp {
  decl : @util.FuncDeclId
  name : String
  value : Bool
}

///|
struct ValueConstInterp {
  decl : @util.FuncDeclId
  name : String
  sort_name : String
  value : ModelValue
}

///|
struct FuncInterpRecord {
  decl : @util.FuncDeclId
  interp : FuncInterp
}

///|
struct UniverseInterp {
  sort : @util.SortId
  name : String
  values : Array[ModelValue]
}

///|
pub struct Model {
  priv value_factory : ValueFactory
  priv universes : Array[UniverseInterp]
  priv bool_consts : Array[BoolConstInterp]
  priv value_consts : Array[ValueConstInterp]
  priv func_interps : Array[FuncInterpRecord]
}

///|
pub fn Model::new() -> Model {
  {
    value_factory: ValueFactory::new(),
    universes: [],
    bool_consts: [],
    value_consts: [],
    func_interps: [],
  }
}

///|
pub fn Model::add_universe_value(
  self : Model,
  sort : @util.SortId,
  name : String,
  value : ModelValue,
) -> Unit {
  for i, universe in self.universes {
    if universe.sort == sort {
      let values = universe.values.copy()
      if !Model::universe_has_value(values, value) {
        values.push(value)
      }
      self.universes[i] = { sort, name, values }
      return
    }
  }
  self.universes.push({ sort, name, values: [value] })
}

///|
pub fn Model::add_bool_const(
  self : Model,
  decl : @util.FuncDeclId,
  name : String,
  value : Bool,
) -> Unit {
  for i, entry in self.bool_consts {
    if entry.decl == decl {
      self.bool_consts[i] = { decl, name, value }
      return
    }
  }
  self.bool_consts.push({ decl, name, value })
}

///|
pub fn Model::add_value_const(
  self : Model,
  decl : @util.FuncDeclId,
  sort : @util.SortId,
  sort_name : String,
  value : ModelValue,
  name? : String = "",
) -> Unit {
  if name == "" {
    return
  }
  for i, entry in self.value_consts {
    if entry.decl == decl {
      self.value_consts[i] = { decl, name, sort_name, value }
      if value.is_universe_member() {
        self.add_universe_value(sort, sort_name, value)
      }
      return
    }
  }
  self.value_consts.push({ decl, name, sort_name, value })
  if value.is_universe_member() {
    self.add_universe_value(sort, sort_name, value)
  }
}

///|
pub fn Model::fresh_uninterpreted_value(
  self : Model,
  sort : @util.SortId,
  sort_name : String,
) -> ModelValue {
  let value = self.value_factory.fresh_uninterpreted(sort, sort_name)
  self.add_universe_value(sort, sort_name, value)
  value
}

///|
fn Model::value_const_value(
  self : Model,
  decl : @util.FuncDeclId,
) -> ModelValue? {
  for entry in self.value_consts {
    if entry.decl == decl {
      return Some(entry.value)
    }
  }
  None
}

///|
fn Model::complete_value_const(
  self : Model,
  decl : @util.FuncDeclId,
  name : String,
  sort : @util.SortId,
  sort_name : String,
) -> ModelValue {
  match self.value_const_value(decl) {
    Some(value) => value
    None => {
      let value = self.fresh_uninterpreted_value(sort, sort_name)
      self.value_consts.push({ decl, name, sort_name, value })
      value
    }
  }
}

///|
pub fn Model::add_func_interp(
  self : Model,
  decl : @util.FuncDeclId,
  interp : FuncInterp,
) -> Unit {
  if !interp.has_display_name() {
    return
  }
  for i, entry in self.func_interps {
    if entry.decl == decl {
      self.func_interps[i] = { decl, interp }
      return
    }
  }
  self.func_interps.push({ decl, interp })
}

///|
fn Model::universe_has_value(
  values : Array[ModelValue],
  value : ModelValue,
) -> Bool {
  for existing in values {
    if existing.to_text() == value.to_text() {
      return true
    }
  }
  false
}

///|
fn compare_model_value(lhs : ModelValue, rhs : ModelValue) -> Int {
  lhs.to_text().compare(rhs.to_text())
}

///|
fn compare_universe_interp(lhs : UniverseInterp, rhs : UniverseInterp) -> Int {
  let lhs_id = lhs.sort.to_int()
  let rhs_id = rhs.sort.to_int()
  if lhs_id < rhs_id {
    -1
  } else if lhs_id > rhs_id {
    1
  } else {
    0
  }
}

///|
fn Model::universe_interps(self : Model) -> Array[UniverseInterp] {
  let entries : Array[UniverseInterp] = []
  for universe in self.universes {
    let values = universe.values.copy()
    values.sort_by(compare_model_value)
    entries.push({ sort: universe.sort, name: universe.name, values })
  }
  entries.sort_by(compare_universe_interp)
  entries
}

///|
pub fn Model::universe_values(
  self : Model,
  sort : @util.SortId,
) -> Array[ModelValue] {
  for universe in self.universes {
    if universe.sort == sort {
      let values = universe.values.copy()
      values.sort_by(compare_model_value)
      return values
    }
  }
  []
}

///|
fn compare_bool_const_interp(
  lhs : BoolConstInterp,
  rhs : BoolConstInterp,
) -> Int {
  let lhs_id = lhs.decl.to_int()
  let rhs_id = rhs.decl.to_int()
  if lhs_id < rhs_id {
    -1
  } else if lhs_id > rhs_id {
    1
  } else {
    0
  }
}

///|
fn Model::bool_const_interps(self : Model) -> Array[BoolConstInterp] {
  let entries = self.bool_consts.copy()
  entries.sort_by(compare_bool_const_interp)
  entries
}

///|
fn compare_value_const_interp(
  lhs : ValueConstInterp,
  rhs : ValueConstInterp,
) -> Int {
  let lhs_id = lhs.decl.to_int()
  let rhs_id = rhs.decl.to_int()
  if lhs_id < rhs_id {
    -1
  } else if lhs_id > rhs_id {
    1
  } else {
    0
  }
}

///|
fn Model::value_const_interps(self : Model) -> Array[ValueConstInterp] {
  let entries : Array[ValueConstInterp] = []
  for entry in self.value_consts {
    if entry.name != "" {
      entries.push(entry)
    }
  }
  entries.sort_by(compare_value_const_interp)
  entries
}

///|
fn compare_func_interp_record(
  lhs : FuncInterpRecord,
  rhs : FuncInterpRecord,
) -> Int {
  let lhs_id = lhs.decl.to_int()
  let rhs_id = rhs.decl.to_int()
  if lhs_id < rhs_id {
    -1
  } else if lhs_id > rhs_id {
    1
  } else {
    0
  }
}

///|
fn Model::function_interps(self : Model) -> Array[FuncInterpRecord] {
  let entries = self.func_interps.copy()
  entries.sort_by(compare_func_interp_record)
  entries
}

///|
fn Model::func_interp_value(
  self : Model,
  decl : @util.FuncDeclId,
) -> FuncInterp? {
  for entry in self.func_interps {
    if entry.decl == decl {
      return Some(entry.interp)
    }
  }
  None
}

///|
pub fn ModelHandle::new(id : Int, result : @util.ResultKind) -> ModelHandle {
  { id, result, disabled: None, stale: false }
}

///|
pub fn ModelHandle::disabled(feature : String) -> ModelHandle {
  {
    id: -1,
    result: @util.ResultKind::NoResult,
    disabled: Some(feature),
    stale: false,
  }
}

///|
pub fn ModelHandle::mark_stale(self : ModelHandle) -> Unit {
  self.stale = true
}

///|
pub fn ModelHandle::view(self : ModelHandle) -> @util.Availability[ModelRef] {
  match self.disabled {
    Some(feature) =>
      @util.Unavailable(@util.AvailabilityReason::Disabled(feature))
    None =>
      if self.stale {
        @util.Unavailable(@util.AvailabilityReason::Stale)
      } else {
        match self.result {
          @util.ResultKind::Sat | @util.ResultKind::Unknown(true) =>
            @util.Available(ModelRef::{ id: self.id, result: self.result })
          @util.ResultKind::NoResult =>
            @util.Unavailable(@util.AvailabilityReason::NoCurrentResult)
          _ =>
            @util.Unavailable(
              @util.AvailabilityReason::wrong_result(
                @util.ResultKind::Sat,
                self.result,
              ),
            )
        }
      }
  }
}

///|
pub fn ModelHandle::to_text(self : ModelHandle) -> String {
  match self.disabled {
    Some(feature) => "model-handle:disabled(\{feature})"
    None => "model-handle#\{self.id}:\{self.result.to_text()}"
  }
}
