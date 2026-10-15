# CLI smoke tests

Run from the repository root on both supported backends:

```sh
moonx moonbit-community/mooncram@0.0.6 test tests --target wasm --timeout-ms 120000
moonx moonbit-community/mooncram@0.0.6 test tests --target native --timeout-ms 120000
```

mooncram builds the CLI separately from the captured program output. Each case
checks stdout, an empty stderr, and the process exit code (zero by default).
Input paths are relative to this document's directory.

## Help and arguments

Both help flags succeed. Missing or extra arguments print usage and fail.

```mooncram moonbit-community/z0
$ src/shell --help
@STDOUT
Usage: z0 <file.smt2>
@STDERR (empty)

$ src/shell -h
@STDOUT
Usage: z0 <file.smt2>
@STDERR (empty)

$ src/shell
@STDOUT
Usage: z0 <file.smt2>
@STDERR (empty)
[1]

$ src/shell one.smt2 two.smt2
@STDOUT
Usage: z0 <file.smt2>
@STDERR (empty)
[1]
```

## File errors

A missing input file produces an IO error and fails. The platform-specific
detail may vary, so match the stable error prefix.

```mooncram moonbit-community/z0
$ src/shell ../smt2/nonexistent-shell-input.smt2
@STDOUT
io: * (glob)
@STDERR (empty)
[1]
```

## Exit and error recovery

An explicit SMT2 exit stops execution before any later commands.

```mooncram moonbit-community/z0
$ src/shell ../smt2/z3_arch_exit_stops_runner.smt2
@STDOUT
before
@STDERR (empty)
```

Recoverable errors allow later commands to run, but still fail the process.

```mooncram moonbit-community/z0
$ src/shell ../smt2/z3_arch_error_recovery_parse_continued.smt2
@STDOUT
before
(error "push count must be non-negative")
after
@STDERR (empty)
[1]
```

Immediate-exit mode stops at the first error and fails the process.

```mooncram moonbit-community/z0
$ src/shell ../smt2/z3_arch_error_recovery_immediate_exit.smt2
@STDOUT
before
(error "push count must be non-negative")
@STDERR (empty)
[1]
```

## File IO

The CLI accepts a path containing Unicode and spaces and prints UTF-8 text.
An empty input file succeeds without output.

```mooncram moonbit-community/z0
$ src/shell "fixtures/中文 input.smt2"
@STDOUT
你好
@STDERR (empty)

$ src/shell fixtures/empty.smt2
@STDOUT (empty)
@STDERR (empty)
```
