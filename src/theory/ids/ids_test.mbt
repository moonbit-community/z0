///|
test "theory_ids_are_opaque_and_stable" {
  let id = @ids.TheoryId::new(7)
  let tv = @ids.TheoryVar::new(11)
  inspect(id.to_int(), content="7")
  inspect(tv.to_int(), content="11")
  inspect(@ids.TheoryId::null().to_int(), content="-1")
  inspect(@ids.TheoryVar::null().to_int(), content="-1")
}

///|
test "theory_ids_format_for_diagnostics" {
  inspect(
    "\{@ids.TheoryId::new(2)}:\{@ids.TheoryVar::new(5)}",
    content="th#2:v#5",
  )
}
