///|
priv struct ParamEntry {
  name : String
  value : ParamValue
}

///|
pub struct Params {
  priv descrs : ParamDescrs
  priv values : Array[ParamEntry]
}

///|
pub fn Params::new(descrs : ParamDescrs) -> Params {
  { descrs, values: [] }
}

///|
fn Params::find_value(self : Params, name : String) -> ParamValue? {
  for entry in self.values {
    if entry.name == name {
      return Some(entry.value)
    }
  }
  None
}

///|
fn Params::set_value(self : Params, name : String, value : ParamValue) -> Unit {
  for i in 0..<self.values.length() {
    if self.values[i].name == name {
      self.values[i] = ParamEntry::{ name, value }
      return
    }
  }
  self.values.push(ParamEntry::{ name, value })
}

///|
fn[T] unknown_param(name : String) -> @util.Availability[T] {
  @util.Unavailable(
    @util.AvailabilityReason::unsupported(
      @util.ReasonUnknown::unsupported_fragment("unknown-param:\{name}"),
    ),
  )
}

///|
fn[T] kind_mismatch(name : String) -> @util.Availability[T] {
  @util.Unavailable(
    @util.AvailabilityReason::unsupported(
      @util.ReasonUnknown::unsupported_fragment("param-kind:\{name}"),
    ),
  )
}

///|
pub fn Params::get_bool(
  self : Params,
  name : String,
) -> @util.Availability[Bool] {
  match self.find_value(name) {
    Some(BoolValue(value)) => @util.Available(value)
    Some(_) => kind_mismatch(name)
    None =>
      match self.descrs.default_value(name) {
        Some(BoolValue(value)) => @util.Available(value)
        Some(_) => kind_mismatch(name)
        None => unknown_param(name)
      }
  }
}

///|
pub fn Params::get_int(self : Params, name : String) -> @util.Availability[Int] {
  match self.find_value(name) {
    Some(IntValue(value)) => @util.Available(value)
    Some(_) => kind_mismatch(name)
    None =>
      match self.descrs.default_value(name) {
        Some(IntValue(value)) => @util.Available(value)
        Some(_) => kind_mismatch(name)
        None => unknown_param(name)
      }
  }
}

///|
pub fn Params::set_bool(
  self : Params,
  name : String,
  value : Bool,
) -> @util.Availability[Bool] {
  self.set_bool_at(name, value, ParamSetStage::setup())
}

///|
pub fn Params::set_bool_at(
  self : Params,
  name : String,
  value : Bool,
  stage : ParamSetStage,
) -> @util.Availability[Bool] {
  match self.descrs.validate_set(name, stage) {
    @util.Unavailable(reason) => @util.Unavailable(reason)
    @util.Available(_) =>
      match self.descrs.default_value(name) {
        Some(BoolValue(_)) => {
          self.set_value(name, BoolValue(value))
          @util.Available(value)
        }
        Some(_) => kind_mismatch(name)
        None => unknown_param(name)
      }
  }
}

///|
pub fn Params::set_int(
  self : Params,
  name : String,
  value : Int,
) -> @util.Availability[Int] {
  self.set_int_at(name, value, ParamSetStage::setup())
}

///|
pub fn Params::set_int_at(
  self : Params,
  name : String,
  value : Int,
  stage : ParamSetStage,
) -> @util.Availability[Int] {
  match self.descrs.validate_set(name, stage) {
    @util.Unavailable(reason) => @util.Unavailable(reason)
    @util.Available(_) =>
      match self.descrs.default_value(name) {
        Some(IntValue(_)) => {
          self.set_value(name, IntValue(value))
          @util.Available(value)
        }
        Some(_) => kind_mismatch(name)
        None => unknown_param(name)
      }
  }
}

///|
pub fn Params::get_string(
  self : Params,
  name : String,
) -> @util.Availability[String] {
  match self.find_value(name) {
    Some(StringValue(value)) => @util.Available(value)
    Some(_) => kind_mismatch(name)
    None =>
      match self.descrs.default_value(name) {
        Some(StringValue(value)) => @util.Available(value)
        Some(_) => kind_mismatch(name)
        None => unknown_param(name)
      }
  }
}

///|
pub fn Params::set_string(
  self : Params,
  name : String,
  value : String,
) -> @util.Availability[String] {
  self.set_string_at(name, value, ParamSetStage::setup())
}

///|
pub fn Params::set_string_at(
  self : Params,
  name : String,
  value : String,
  stage : ParamSetStage,
) -> @util.Availability[String] {
  match self.descrs.validate_set(name, stage) {
    @util.Unavailable(reason) => @util.Unavailable(reason)
    @util.Available(_) =>
      match self.descrs.default_value(name) {
        Some(StringValue(_)) => {
          self.set_value(name, StringValue(value))
          @util.Available(value)
        }
        Some(_) => kind_mismatch(name)
        None => unknown_param(name)
      }
  }
}
