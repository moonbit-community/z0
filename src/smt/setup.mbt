///|
pub(all) enum SmtSetupMode {
  CFG_BASIC
  CFG_LOGIC(String)
  CFG_AUTO
} derive(Eq)

///|
pub fn SmtSetupMode::basic() -> SmtSetupMode {
  CFG_BASIC
}

///|
pub fn SmtSetupMode::logic(logic : String) -> SmtSetupMode {
  CFG_LOGIC(logic)
}

///|
pub fn SmtSetupMode::auto() -> SmtSetupMode {
  CFG_AUTO
}

///|
pub fn setup_selected_names(
  registry : TheoryRegistry,
  mode : SmtSetupMode,
) -> String {
  let names : Array[String] = []
  for factory in registry.selected_factories(mode) {
    names.push(theory_factory_name(factory))
  }
  names.join(",")
}
