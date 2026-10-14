///|
test "source_span_formats_line_and_column" {
  let span = @source.SourceSpan::new(
    start=@source.SourcePos::new(line=1, column=4, offset=3),
    end=@source.SourcePos::new(line=1, column=5, offset=4),
  )
  inspect(span, content="line 1, col 4")
}
