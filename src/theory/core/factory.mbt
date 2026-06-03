///|
pub struct TheoryFactoryDescriptor {
  priv id : @ids.TheoryId
  priv name : String
  priv families : Array[@ast.FamilyId]
  priv logics : Array[String]
  priv auto_config : Bool
}

///|
pub fn TheoryFactoryDescriptor::new(
  id~ : @ids.TheoryId,
  name~ : String,
  families~ : Array[@ast.FamilyId],
  logics~ : Array[String],
  auto_config~ : Bool,
) -> TheoryFactoryDescriptor {
  { id, name, families: families.copy(), logics: logics.copy(), auto_config }
}

///|
pub fn TheoryFactoryDescriptor::id(
  self : TheoryFactoryDescriptor,
) -> @ids.TheoryId {
  self.id
}

///|
pub fn TheoryFactoryDescriptor::name(self : TheoryFactoryDescriptor) -> String {
  self.name
}

///|
pub fn TheoryFactoryDescriptor::families(
  self : TheoryFactoryDescriptor,
) -> Array[@ast.FamilyId] {
  self.families.copy()
}

///|
pub fn TheoryFactoryDescriptor::matches_family(
  self : TheoryFactoryDescriptor,
  family : @ast.FamilyId,
) -> Bool {
  for candidate in self.families {
    if candidate == family {
      return true
    }
  }
  false
}

///|
pub fn TheoryFactoryDescriptor::matches_logic(
  self : TheoryFactoryDescriptor,
  logic : String,
) -> Bool {
  for candidate in self.logics {
    if candidate == logic {
      return true
    }
  }
  false
}

///|
pub fn TheoryFactoryDescriptor::auto_config(
  self : TheoryFactoryDescriptor,
) -> Bool {
  self.auto_config
}

///|
pub struct TheoryFactory {
  priv descriptor : TheoryFactoryDescriptor
  priv create_fn : () -> TheoryPlugin
}

///|
pub fn TheoryFactory::new(
  descriptor : TheoryFactoryDescriptor,
  create : () -> TheoryPlugin,
) -> TheoryFactory {
  { descriptor, create_fn: create }
}

///|
pub fn TheoryFactory::descriptor(
  self : TheoryFactory,
) -> TheoryFactoryDescriptor {
  self.descriptor
}

///|
pub fn TheoryFactory::create(self : TheoryFactory) -> TheoryPlugin {
  (self.create_fn)()
}
