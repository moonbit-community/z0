///|
test "type_error_formats_with_span" {
  let span = @source.SourceSpan::new(
    start=@source.SourcePos::new(line=2, column=7, offset=10),
    end=@source.SourcePos::new(line=2, column=11, offset=14),
  )
  let error = @type_error.TypeError("expected Bool", Some(span))
  inspect(error.format(), content="line 2, col 7: expected Bool")
}

///|
test "type_error_formats_without_span" {
  let error = @type_error.TypeError("unknown sort", None)
  inspect(error.format(), content="type: unknown sort")
}
