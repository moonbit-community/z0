///|
fn model_converter_availability_text(
  result : @util.Availability[@model.Model],
) -> String {
  match result {
    Available(model) => model.format()
    Unavailable(reason) => reason.to_text()
  }
}

///|
fn string_array_availability_text(
  result : @util.Availability[Array[String]],
) -> String {
  match result {
    Available(values) => values.join(",")
    Unavailable(reason) => reason.to_text()
  }
}

///|
fn proof_converter_availability_text(
  result : @util.Availability[@proof.ProofObject],
) -> String {
  match result {
    Available(proof) => proof.root_text()
    Unavailable(reason) => reason.to_text()
  }
}

///|
test "model_converter_identity_and_generic_steps_are_explicit" {
  let model = @model.Model::new()
  let generic = @converters.GenericModelConverter::new()
  generic.add("macro-value")
  generic.hide("aux!0")
  let converter = generic.as_model_converter()
  inspect(converter.steps_text(), content="identity>add:macro-value>hide:aux!0")
  inspect(
    model_converter_availability_text(converter.apply_model(model)),
    content="()",
  )
}

///|
test "model_converter_unsupported_is_typed" {
  let converter = @converters.ModelConverter::unsupported(
    "model-converter-seed",
  )
  inspect(
    model_converter_availability_text(
      converter.apply_model(@model.Model::new()),
    ),
    content="unsupported(model-converter-seed)",
  )
  inspect(
    string_array_availability_text(converter.get_units([])),
    content="unsupported(model-converter-seed)",
  )
  inspect(
    string_array_availability_text(converter.convert_initialize_values([])),
    content="unsupported(model-converter-seed)",
  )
}

///|
test "generic_model_converter_units_follow_concat_order_and_hide_aux" {
  let outer = @converters.GenericModelConverter::new()
  outer.add_unit("p", true)
  outer.hide("aux!0")
  let inner = @converters.GenericModelConverter::new()
  inner.add_unit("aux!0", true)
  inner.add_unit("q", false)
  let converter = outer.as_model_converter().concat(inner.as_model_converter())
  inspect(
    string_array_availability_text(
      converter.get_units(["aux!0=false", "r=true"]),
    ),
    content="r=true,q=false,p=true",
  )
}

///|
test "generic_model_converter_initialize_values_follow_concat_order" {
  let outer = @converters.GenericModelConverter::new()
  outer.add_initialize_value("p", "true")
  let inner = @converters.GenericModelConverter::new()
  inner.add_initialize_value("q", "false")
  let converter = outer.as_model_converter().concat(inner.as_model_converter())
  inspect(
    string_array_availability_text(
      converter.convert_initialize_values(["seed=@u0"]),
    ),
    content="seed=@u0,q=false,p=true",
  )
}

///|
test "proof_converter_identity_labels_and_unsupported_are_explicit" {
  let identity = @converters.ProofConverter::identity()
  match identity.apply_labels(["a", "b"]) {
    Available(labels) => inspect(labels.join(","), content="a,b")
    Unavailable(reason) => inspect(reason.to_text(), content="a,b")
  }
  let proof = @proof.ProofObject::from_root_and_hints("false", [])
  inspect(
    proof_converter_availability_text(identity.apply_proof(proof)),
    content="false",
  )
  let unsupported = @converters.ProofConverter::unsupported(
    "proof-converter-seed",
  )
  inspect(
    proof_converter_availability_text(unsupported.apply_proof(proof)),
    content="unsupported(proof-converter-seed)",
  )
}

///|
test "generic_proof_converter_appends_labels_explicitly" {
  let generic = @converters.GenericProofConverter::new()
  generic.add_label("tseitin-aux:tseitin!0")
  let converter = generic.as_proof_converter()
  inspect(
    converter.steps_text(),
    content="identity>label:tseitin-aux:tseitin!0",
  )
  match converter.apply_labels(["named-input"]) {
    Available(labels) =>
      inspect(labels.join(","), content="named-input,tseitin-aux:tseitin!0")
    Unavailable(reason) =>
      inspect(reason.to_text(), content="named-input,tseitin-aux:tseitin!0")
  }
}
