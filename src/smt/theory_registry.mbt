///|
pub struct TheoryRegistry {
  priv factories : Array[@theory_core.TheoryFactory]
}

///|
pub fn TheoryRegistry::new() -> TheoryRegistry {
  { factories: [] }
}

///|
pub fn TheoryRegistry::register(
  self : TheoryRegistry,
  factory : @theory_core.TheoryFactory,
) -> Unit {
  self.factories.push(factory)
}

///|
pub fn TheoryRegistry::factories(
  self : TheoryRegistry,
) -> Array[@theory_core.TheoryFactory] {
  self.factories.copy()
}

///|
pub fn TheoryRegistry::selected_factories(
  self : TheoryRegistry,
  mode : SmtSetupMode,
) -> Array[@theory_core.TheoryFactory] {
  let selected : Array[@theory_core.TheoryFactory] = []
  match mode {
    CFG_BASIC => ()
    CFG_LOGIC(logic) =>
      for factory in self.factories {
        if factory.descriptor().matches_logic(logic) {
          selected.push(factory)
        }
      }
    CFG_AUTO =>
      for factory in self.factories {
        if factory.descriptor().auto_config() {
          selected.push(factory)
        }
      }
  }
  selected
}

///|
pub fn TheoryRegistry::instantiate(
  self : TheoryRegistry,
  mode : SmtSetupMode,
) -> Array[@theory_core.TheoryPlugin] {
  let plugins : Array[@theory_core.TheoryPlugin] = []
  for factory in self.selected_factories(mode) {
    plugins.push(factory.create())
  }
  plugins
}
