///|
pub struct ModelConverter {
  priv steps : Array[String]
  priv unit_actions : Array[ModelUnitAction]
  priv initialize_values : Array[String]
  priv unsupported : String?
}

///|
pub fn ModelConverter::identity() -> ModelConverter {
  {
    steps: ["identity"],
    unit_actions: [],
    initialize_values: [],
    unsupported: None,
  }
}

///|
pub fn ModelConverter::unsupported(feature : String) -> ModelConverter {
  {
    steps: ["unsupported:\{feature}"],
    unit_actions: [],
    initialize_values: [],
    unsupported: Some(feature),
  }
}

///|
fn ModelConverter::append_step(self : ModelConverter, step : String) -> Unit {
  self.steps.push(step)
}

///|
struct ModelUnitAction {
  name : String
  value : Bool?
}

///|
fn ModelUnitAction::add(name : String, value : Bool) -> ModelUnitAction {
  { name, value: Some(value) }
}

///|
fn ModelUnitAction::hide(name : String) -> ModelUnitAction {
  { name, value: None }
}

///|
fn model_unit_text(name : String, value : Bool) -> String {
  "\{name}=\{value}"
}

///|
fn remove_model_unit(units : Array[String], name : String) -> Unit {
  let kept : Array[String] = []
  let true_unit = model_unit_text(name, true)
  let false_unit = model_unit_text(name, false)
  for unit in units {
    if unit != true_unit && unit != false_unit {
      kept.push(unit)
    }
  }
  units.truncate(0)
  for unit in kept {
    units.push(unit)
  }
}

///|
fn append_model_unit(
  units : Array[String],
  name : String,
  value : Bool,
) -> Unit {
  remove_model_unit(units, name)
  units.push(model_unit_text(name, value))
}

///|
fn ModelConverter::append_unit_action(
  self : ModelConverter,
  action : ModelUnitAction,
) -> Unit {
  self.unit_actions.push(action)
}

///|
fn ModelConverter::append_initialize_value(
  self : ModelConverter,
  name : String,
  value : String,
) -> Unit {
  self.initialize_values.push("\{name}=\{value}")
}

///|
pub fn ModelConverter::concat(
  self : ModelConverter,
  next : ModelConverter,
) -> ModelConverter {
  let steps = self.steps.copy()
  for step in next.steps {
    steps.push(step)
  }
  let unit_actions = next.unit_actions.copy()
  for action in self.unit_actions {
    unit_actions.push(action)
  }
  let initialize_values = next.initialize_values.copy()
  for value in self.initialize_values {
    initialize_values.push(value)
  }
  {
    steps,
    unit_actions,
    initialize_values,
    unsupported: match self.unsupported {
      Some(feature) => Some(feature)
      None => next.unsupported
    },
  }
}

///|
pub fn ModelConverter::get_units(
  self : ModelConverter,
  units : Array[String],
) -> @util.Availability[Array[String]] {
  match self.unsupported {
    Some(feature) => converter_unavailable(feature)
    None => {
      let result = units.copy()
      for action in self.unit_actions {
        match action.value {
          Some(value) => append_model_unit(result, action.name, value)
          None => remove_model_unit(result, action.name)
        }
      }
      @util.Available(result)
    }
  }
}

///|
pub fn ModelConverter::convert_initialize_values(
  self : ModelConverter,
  values : Array[String],
) -> @util.Availability[Array[String]] {
  match self.unsupported {
    Some(feature) => converter_unavailable(feature)
    None => {
      let result = values.copy()
      for value in self.initialize_values {
        result.push(value)
      }
      @util.Available(result)
    }
  }
}

///|
pub fn ModelConverter::steps_text(self : ModelConverter) -> String {
  converter_join_steps(self.steps)
}

///|
pub fn ModelConverter::apply_model(
  self : ModelConverter,
  model : @model.Model,
) -> @util.Availability[@model.Model] {
  match self.unsupported {
    Some(feature) => converter_unavailable(feature)
    None => @util.Available(model)
  }
}

///|
pub fn ModelConverter::translate(
  self : ModelConverter,
  _translator : @ast.AstTranslator,
) -> @util.Availability[ModelConverter] {
  match self.unsupported {
    Some(feature) => converter_unavailable(feature)
    None => @util.Available(self)
  }
}

///|
pub struct GenericModelConverter {
  priv converter : ModelConverter
}

///|
pub fn GenericModelConverter::new() -> GenericModelConverter {
  { converter: ModelConverter::identity() }
}

///|
pub fn GenericModelConverter::add(
  self : GenericModelConverter,
  name : String,
) -> Unit {
  self.converter.append_step("add:\{name}")
}

///|
pub fn GenericModelConverter::add_unit(
  self : GenericModelConverter,
  name : String,
  value : Bool,
) -> Unit {
  self.converter.append_step("unit:\{model_unit_text(name, value)}")
  self.converter.append_unit_action(ModelUnitAction::add(name, value))
}

///|
pub fn GenericModelConverter::add_initialize_value(
  self : GenericModelConverter,
  name : String,
  value : String,
) -> Unit {
  self.converter.append_step("init:\{name}=\{value}")
  self.converter.append_initialize_value(name, value)
}

///|
pub fn GenericModelConverter::hide(
  self : GenericModelConverter,
  name : String,
) -> Unit {
  self.converter.append_step("hide:\{name}")
  self.converter.append_unit_action(ModelUnitAction::hide(name))
}

///|
pub fn GenericModelConverter::as_model_converter(
  self : GenericModelConverter,
) -> ModelConverter {
  self.converter
}
