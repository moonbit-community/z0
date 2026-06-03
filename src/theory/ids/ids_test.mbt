///|
test "theory_ids_are_opaque_and_stable" {
  let id = TheoryId::new(7)
  let tv = TheoryVar::new(11)
  inspect(id.to_int(), content="7")
  inspect(tv.to_int(), content="11")
  inspect(TheoryId::null().to_int(), content="-1")
  inspect(TheoryVar::null().to_int(), content="-1")
}

///|
test "theory_ids_format_for_diagnostics" {
  inspect("\{TheoryId::new(2)}:\{TheoryVar::new(5)}", content="th#2:v#5")
}
