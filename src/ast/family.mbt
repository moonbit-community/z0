///|
pub struct FamilyId {
  priv value : Int
} derive(Eq, Compare, Hash)

///|
pub fn FamilyId::new(value : Int) -> FamilyId {
  { value, }
}

///|
pub fn FamilyId::to_int(self : FamilyId) -> Int {
  self.value
}

///|
pub impl Show for FamilyId with fn output(self, logger) {
  logger.write_string("family#\{self.value}")
}

///|
pub(all) enum DeclPluginHook {
  PluginClone
  PluginInherit
  ParameterTranslation
  MkFresh
  IsValue
  IsModelValue
  AreEqual
  AreDistinct
  GetSomeValue
  IsConsideredUninterpreted
  Translate
} derive(Eq)

///|
pub fn DeclPluginHook::name(self : DeclPluginHook) -> String {
  match self {
    PluginClone => "clone"
    PluginInherit => "inherit"
    ParameterTranslation => "parameter_translation"
    MkFresh => "mk_fresh"
    IsValue => "is_value"
    IsModelValue => "is_model_value"
    AreEqual => "are_equal"
    AreDistinct => "are_distinct"
    GetSomeValue => "get_some_value"
    IsConsideredUninterpreted => "is_considered_uninterpreted"
    Translate => "translate"
  }
}

///|
fn default_decl_plugin_hooks() -> Array[DeclPluginHook] {
  [
    PluginClone,
    PluginInherit,
    ParameterTranslation,
    MkFresh,
    IsValue,
    IsModelValue,
    AreEqual,
    AreDistinct,
    GetSomeValue,
    IsConsideredUninterpreted,
    Translate,
  ]
}

///|
pub struct FamilyDescriptor {
  priv id : FamilyId
  priv name : String
  priv supported : Bool
  priv owner : String
}

///|
pub fn FamilyDescriptor::new(
  id~ : FamilyId,
  name~ : String,
  supported~ : Bool,
  owner~ : String,
) -> FamilyDescriptor {
  { id, name, supported, owner }
}

///|
pub fn FamilyDescriptor::id(self : FamilyDescriptor) -> FamilyId {
  self.id
}

///|
pub fn FamilyDescriptor::name(self : FamilyDescriptor) -> String {
  self.name
}

///|
pub fn FamilyDescriptor::owner(self : FamilyDescriptor) -> String {
  self.owner
}

///|
pub fn FamilyDescriptor::is_supported(self : FamilyDescriptor) -> Bool {
  self.supported
}

///|
pub fn FamilyDescriptor::support_text(self : FamilyDescriptor) -> String {
  if self.supported {
    "supported:\{self.name}"
  } else {
    "unsupported:\{self.name}"
  }
}

///|
pub fn FamilyDescriptor::has_hook(
  _self : FamilyDescriptor,
  hook : DeclPluginHook,
) -> Bool {
  for candidate in default_decl_plugin_hooks() {
    if candidate == hook {
      return true
    }
  }
  false
}

///|
pub fn FamilyDescriptor::hook_status(
  self : FamilyDescriptor,
  hook : DeclPluginHook,
) -> @util.Availability[Unit] {
  if !self.has_hook(hook) {
    @util.Unavailable(
      @util.Unsupported(
        @util.ReasonUnknown::unsupported_fragment("\{self.name}.\{hook.name()}"),
      ),
    )
  } else if !self.supported {
    @util.Unavailable(
      @util.Unsupported(
        @util.ReasonUnknown::unsupported_fragment("\{self.name}.\{hook.name()}"),
      ),
    )
  } else {
    @util.Available(())
  }
}

///|
pub fn FamilyDescriptor::hook_manifest_text(_self : FamilyDescriptor) -> String {
  [ for hook in default_decl_plugin_hooks() => hook.name() ].join(",")
}

///|
fn default_family_descriptors() -> Array[FamilyDescriptor] {
  [
    FamilyDescriptor::new(
      id=FamilyId::new(0),
      name="Bool",
      supported=true,
      owner="Bool internalizer/SAT",
    ),
    FamilyDescriptor::new(
      id=FamilyId::new(1),
      name="UF",
      supported=true,
      owner="EUF/egraph",
    ),
    FamilyDescriptor::new(
      id=FamilyId::new(2),
      name="arith",
      supported=true,
      owner="src/theory/arith_lite",
    ),
    FamilyDescriptor::new(
      id=FamilyId::new(3),
      name="array",
      supported=false,
      owner="followup array theory",
    ),
    FamilyDescriptor::new(
      id=FamilyId::new(4),
      name="bv",
      supported=false,
      owner="followup bit-vector theory",
    ),
    FamilyDescriptor::new(
      id=FamilyId::new(5),
      name="datatype",
      supported=false,
      owner="followup datatype theory",
    ),
    FamilyDescriptor::new(
      id=FamilyId::new(6),
      name="seq",
      supported=false,
      owner="followup sequence theory",
    ),
  ]
}
