///|
test "unsupported_error_formats_with_span" {
  let span = @source.SourceSpan::new(
    start=@source.SourcePos::new(line=3, column=2, offset=20),
    end=@source.SourcePos::new(line=3, column=9, offset=27),
  )
  let error = @unsupported_error.UnsupportedError(
    "arrays are not supported",
    Some(span),
  )
  inspect(error.format(), content="line 3, col 2: arrays are not supported")
}

///|
test "unsupported_error_formats_without_span" {
  let error = @unsupported_error.UnsupportedError(
    "quantifiers are not supported",
    None,
  )
  inspect(error.format(), content="unsupported: quantifiers are not supported")
}
