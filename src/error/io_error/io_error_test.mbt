///|
test "io_error_formats_with_prefix" {
  let error = @io_error.IoError("file not found")
  inspect(error.format(), content="io: file not found")
}
