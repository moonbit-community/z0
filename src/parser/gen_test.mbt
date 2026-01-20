///|
// test {
//   let files = @fs.read_dir("smt2")
//   let buf = StringBuilder::new()
//   for file in files {
//     if file.has_suffix(".smt2") {
//       let test_block =
//         $|test "\{file}" {
//         $|  let source = @fs.read_file_to_string("./smt2/\{file}")
//         $|  ignore(parse_smtlib(source))
//         #|}
//         #|
//       buf.write_string(test_block)
//     }
//   }
//   @fs.write_string_to_file("./parser_test", buf.to_string())
// }
