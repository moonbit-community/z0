///|
pub struct ProofConverter {
  priv steps : Array[String]
  priv labels : Array[String]
  priv unsupported : String?
}

///|
pub fn ProofConverter::identity() -> ProofConverter {
  { steps: ["identity"], labels: [], unsupported: None }
}

///|
pub fn ProofConverter::unsupported(feature : String) -> ProofConverter {
  { steps: ["unsupported:\{feature}"], labels: [], unsupported: Some(feature) }
}

///|
fn ProofConverter::append_label(self : ProofConverter, label : String) -> Unit {
  self.steps.push("label:\{label}")
  self.labels.push(label)
}

///|
pub fn ProofConverter::concat(
  self : ProofConverter,
  next : ProofConverter,
) -> ProofConverter {
  let steps = self.steps.copy()
  for step in next.steps {
    steps.push(step)
  }
  let labels = self.labels.copy()
  for label in next.labels {
    labels.push(label)
  }
  {
    steps,
    labels,
    unsupported: match self.unsupported {
      Some(feature) => Some(feature)
      None => next.unsupported
    },
  }
}

///|
pub fn ProofConverter::steps_text(self : ProofConverter) -> String {
  converter_join_steps(self.steps)
}

///|
pub fn ProofConverter::apply_proof(
  self : ProofConverter,
  proof : @proof.ProofObject,
) -> @util.Availability[@proof.ProofObject] {
  match self.unsupported {
    Some(feature) => converter_unavailable(feature)
    None => @util.Available(proof)
  }
}

///|
pub fn ProofConverter::apply_labels(
  self : ProofConverter,
  labels : Array[String],
) -> @util.Availability[Array[String]] {
  match self.unsupported {
    Some(feature) => converter_unavailable(feature)
    None => {
      let result = labels.copy()
      for label in self.labels {
        result.push(label)
      }
      @util.Available(result)
    }
  }
}

///|
pub fn ProofConverter::translate(
  self : ProofConverter,
  _translator : @ast.AstTranslator,
) -> @util.Availability[ProofConverter] {
  match self.unsupported {
    Some(feature) => converter_unavailable(feature)
    None => @util.Available(self)
  }
}

///|
pub struct GenericProofConverter {
  priv converter : ProofConverter
}

///|
pub fn GenericProofConverter::new() -> GenericProofConverter {
  { converter: ProofConverter::identity() }
}

///|
pub fn GenericProofConverter::add_label(
  self : GenericProofConverter,
  label : String,
) -> Unit {
  self.converter.append_label(label)
}

///|
pub fn GenericProofConverter::as_proof_converter(
  self : GenericProofConverter,
) -> ProofConverter {
  self.converter
}
