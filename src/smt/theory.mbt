///|
fn theory_factory_name(factory : @theory_core.TheoryFactory) -> String {
  factory.descriptor().name()
}
