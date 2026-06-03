///|
test "parse_error_formats_with_span" {
  let span = @source.SourceSpan::new(
    start=@source.SourcePos::new(line=1, column=4, offset=3),
    end=@source.SourcePos::new(line=1, column=5, offset=4),
  )
  let error = @parse_error.ParseError("unexpected ')'", Some(span))
  inspect(error.format(), content="line 1, col 4: unexpected ')'")
}

///|
test "parse_error_formats_without_span" {
  let error = @parse_error.ParseError("unexpected end of input", None)
  inspect(error.format(), content="parse: unexpected end of input")
}
