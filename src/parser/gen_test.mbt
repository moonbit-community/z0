///|
// test {
//     let files = @fs.read_dir("smt2")
//     let buf = StringBuilder::new()
//     for file in files {
//       if file.chop_suffix(".smt2") is Some(base) { 
//         let test_block =
//           $|test "\{base}" {
//           $|  run_smt("\{base}")
//           #|}
//           #|
//         buf.write_string(test_block)
//       }
//     }
//     @fs.write_string_to_file("./parser_test", buf.to_string())
// }
